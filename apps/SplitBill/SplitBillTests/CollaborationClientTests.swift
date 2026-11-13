import Foundation
import Testing
@testable import SplitBill

private nonisolated final class CollaborationURLProtocolStub: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@Suite("Collaboration HTTP Client & State Store Tests", .serialized)
struct CollaborationClientTests {

    private func makeStubbedService() -> HTTPCollaborationService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CollaborationURLProtocolStub.self]
        let session = URLSession(configuration: config)
        return HTTPCollaborationService(
            baseURL: URL(string: "http://127.0.0.1:3000"),
            session: session
        )
    }

    private func makeSampleSnapshotJSON(version: Int = 1, status: String = "ACTIVE") -> String {
        let p1 = "11111111-1111-4111-8111-111111111111"
        let p2 = "22222222-2222-4222-8222-222222222222"
        let i1 = "33333333-3333-4333-8333-333333333333"
        return """
        {
          "sessionId": "sess-uuid",
          "shareCode": "ABCD2345",
          "status": "\(status)",
          "version": \(version),
          "includeImage": false,
          "imageHiddenByModeration": false,
          "imageBase64OptIn": null,
          "reportCount": 0,
          "expiresAt": "2026-11-13T20:00:00.000Z",
          "receipt": {
            "id": "44444444-4444-4444-8444-444444444444",
            "title": "Taqueria",
            "date": "2026-11-12T20:00:00.000Z",
            "currency": "MXN",
            "subtotalCents": 1000,
            "taxCents": 160,
            "tipCents": 100,
            "totalCents": 1260,
            "items": [
              {
                "id": "\(i1)",
                "name": "Orden Tacos",
                "quantity": 1,
                "priceCents": 1000,
                "claimantIds": ["\(p1)", "\(p2)"]
              }
            ],
            "participants": [
              { "id": "\(p1)", "name": "Host", "isHost": true },
              { "id": "\(p2)", "name": "Guest", "isHost": false }
            ]
          }
        }
        """
    }

    @Test("joinSession decodes guestToken, snapshot, and computes exact penny preview")
    func joinAndDomainPreview() async throws {
        let service = makeStubbedService()
        let bodyJSON = """
        {
          "shareCode": "ABCD2345",
          "sessionToken": "secret-guest-token",
          "participantId": "22222222-2222-4222-8222-222222222222",
          "snapshot": \(makeSampleSnapshotJSON(version: 2))
        }
        """

        CollaborationURLProtocolStub.handler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/v1/shared-sessions/ABCD2345/join")
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            return (response, Data(bodyJSON.utf8))
        }

        let code = try ShareCode(rawValue: "abcd2345")
        let joined = try await service.joinSession(code: code, displayName: "Guest")
        #expect(joined.sessionToken == "secret-guest-token")
        #expect(joined.snapshot.version == 2)

        let domain = try joined.snapshot.toDomainPreview()
        #expect(domain.participants.count == 2)
        #expect(domain.preview.grandTotal.amountInMinorUnits == 1260)
        #expect(domain.preview.splitResult.totalAllocated.amountInMinorUnits == 1260)
    }

    @Test("toggleClaim maps 409 Conflict to CollaborationError.versionConflict with serverVersion")
    func conflictMapsServerVersion() async throws {
        let service = makeStubbedService()

        CollaborationURLProtocolStub.handler = { request in
            #expect(request.value(forHTTPHeaderField: "x-session-token") == "tok-123")
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(
                url: url,
                statusCode: 409,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            let errJSON = #"{"message":"Version conflict","serverVersion":7}"#
            return (response, Data(errJSON.utf8))
        }

        let code = try ShareCode(rawValue: "ABCD2345")
        await #expect(throws: CollaborationError.versionConflict(serverVersion: 7)) {
            _ = try await service.toggleClaim(
                code: code,
                sessionToken: "tok-123",
                itemId: UUID(),
                action: .claim,
                expectedVersion: 2
            )
        }
    }

    @Test("fetchSnapshot returns nil when server reports unchanged: true")
    func fetchSnapshotUnchanged() async throws {
        let service = makeStubbedService()

        CollaborationURLProtocolStub.handler = { request in
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            return (response, Data(#"{"unchanged":true,"version":3,"status":"ACTIVE"}"#.utf8))
        }

        let code = try ShareCode(rawValue: "ABCD2345")
        let result = try await service.fetchSnapshot(code: code, sessionToken: "tok", sinceVersion: 3)
        #expect(result == nil)
    }

    @Test("410 Gone and 403 Quarantine map to typed CollaborationError cases")
    func goneAndQuarantinedErrors() async throws {
        let service = makeStubbedService()
        let code = try ShareCode(rawValue: "ABCD2345")

        CollaborationURLProtocolStub.handler = { request in
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: 410, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"message":"Expired"}"#.utf8))
        }
        await #expect(throws: CollaborationError.sessionExpired) {
            _ = try await service.fetchSnapshot(code: code, sessionToken: "tok", sinceVersion: nil)
        }

        CollaborationURLProtocolStub.handler = { request in
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: 403, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"message":"Session quarantined by moderation"}"#.utf8))
        }
        await #expect(throws: CollaborationError.sessionQuarantined) {
            _ = try await service.joinSession(code: code, displayName: "Late")
        }
    }

    @Test("InMemoryCollaborationStateStore persists tokens, hidden images, and local blocklist")
    func stateStorePersistence() {
        let store = InMemoryCollaborationStateStore()
        store.saveSessionToken("token-abc", forShareCode: "abcd2345")
        #expect(store.loadSessionToken(forShareCode: "ABCD2345") == "token-abc")

        store.deleteSessionToken(forShareCode: "ABCD2345")
        #expect(store.loadSessionToken(forShareCode: "ABCD2345") == nil)

        store.setImageHidden(true, forSessionID: "sess-1")
        #expect(store.isImageHidden(forSessionID: "sess-1"))

        store.blockSession(sessionIDOrCode: "abcd2345")
        #expect(store.isSessionBlocked(sessionIDOrCode: "ABCD2345"))
    }
}
