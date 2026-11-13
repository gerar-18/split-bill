import Foundation

/// Contract for live collaborative session networking (REST + SSE).
nonisolated protocol CollaborationServicing: Sendable {
    func createSession(
        _ request: CreateSharedSessionRequestDTO
    ) async throws(CollaborationError) -> CreateOrJoinSessionResponseDTO

    func joinSession(
        code: ShareCode,
        displayName: String
    ) async throws(CollaborationError) -> CreateOrJoinSessionResponseDTO

    func fetchSnapshot(
        code: ShareCode,
        sessionToken: String,
        sinceVersion: Int?
    ) async throws(CollaborationError) -> CollaborationSnapshotDTO?

    func toggleClaim(
        code: ShareCode,
        sessionToken: String,
        itemId: UUID,
        action: ClaimAction,
        expectedVersion: Int
    ) async throws(CollaborationError) -> CollaborationSnapshotDTO

    func reportSession(
        code: ShareCode,
        sessionToken: String,
        reason: ModerationReportReason,
        note: String?
    ) async throws(CollaborationError) -> ReportSessionResponseDTO

    func leaveSession(
        code: ShareCode,
        sessionToken: String
    ) async throws(CollaborationError)

    func closeSession(
        code: ShareCode,
        sessionToken: String
    ) async throws(CollaborationError)

    func streamEvents(
        code: ShareCode,
        sessionToken: String
    ) -> AsyncThrowingStream<CollaborationSSEEventDTO, Error>
}

/// Pure Apple SDK (`URLSession` + `URLSession.bytes`) collaboration client.
nonisolated final class HTTPCollaborationService: CollaborationServicing, Sendable {
    private let baseURL: URL
    private let session: URLSession

    nonisolated init(baseURL: URL? = nil, session: URLSession? = nil) {
        if let baseURL {
            self.baseURL = baseURL
        } else if let envUrlString = ProcessInfo.processInfo.environment["SPLITBILL_API_URL"],
                  let envUrl = URL(string: envUrlString) {
            self.baseURL = envUrl
        } else if let defaultURL = URL(string: "http://127.0.0.1:3000") {
            self.baseURL = defaultURL
        } else {
            preconditionFailure("Invalid default SplitBill API URL")
        }

        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 300
            self.session = URLSession(configuration: config)
        }
    }

    func createSession(
        _ requestDTO: CreateSharedSessionRequestDTO
    ) async throws(CollaborationError) -> CreateOrJoinSessionResponseDTO {
        let url = baseURL.appendingPathComponent("v1/shared-sessions")
        return try await sendJSONRequest(
            url: url,
            method: "POST",
            body: requestDTO,
            sessionToken: nil,
            responseType: CreateOrJoinSessionResponseDTO.self
        )
    }

    func joinSession(
        code: ShareCode,
        displayName: String
    ) async throws(CollaborationError) -> CreateOrJoinSessionResponseDTO {
        let url = baseURL.appendingPathComponent("v1/shared-sessions/\(code.value)/join")
        return try await sendJSONRequest(
            url: url,
            method: "POST",
            body: JoinSharedSessionRequestDTO(displayName: displayName),
            sessionToken: nil,
            responseType: CreateOrJoinSessionResponseDTO.self
        )
    }

    func fetchSnapshot(
        code: ShareCode,
        sessionToken: String,
        sinceVersion: Int?
    ) async throws(CollaborationError) -> CollaborationSnapshotDTO? {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("v1/shared-sessions/\(code.value)"),
            resolvingAgainstBaseURL: false
        )
        if let sinceVersion {
            components?.queryItems = [URLQueryItem(name: "sinceVersion", value: String(sinceVersion))]
        }
        guard let url = components?.url else {
            throw .invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(sessionToken, forHTTPHeaderField: "x-session-token")

        let (data, http) = try await performDataRequest(request)
        try validateStatus(http.statusCode, data: data)

        if let unchanged = try? JSONDecoder().decode(CollaborationUnchangedDTO.self, from: data),
           unchanged.unchanged {
            return nil
        }

        do {
            return try JSONDecoder().decode(CollaborationSnapshotDTO.self, from: data)
        } catch {
            throw .decodingFailed
        }
    }

    func toggleClaim(
        code: ShareCode,
        sessionToken: String,
        itemId: UUID,
        action: ClaimAction,
        expectedVersion: Int
    ) async throws(CollaborationError) -> CollaborationSnapshotDTO {
        let url = baseURL.appendingPathComponent("v1/shared-sessions/\(code.value)/claims")
        return try await sendJSONRequest(
            url: url,
            method: "POST",
            body: ToggleClaimRequestDTO(
                itemId: itemId.uuidString.lowercased(),
                action: action.rawValue,
                expectedVersion: expectedVersion
            ),
            sessionToken: sessionToken,
            responseType: CollaborationSnapshotDTO.self
        )
    }

    func reportSession(
        code: ShareCode,
        sessionToken: String,
        reason: ModerationReportReason,
        note: String?
    ) async throws(CollaborationError) -> ReportSessionResponseDTO {
        let url = baseURL.appendingPathComponent("v1/shared-sessions/\(code.value)/reports")
        return try await sendJSONRequest(
            url: url,
            method: "POST",
            body: ReportSessionRequestDTO(reason: reason.rawValue, note: note),
            sessionToken: sessionToken,
            responseType: ReportSessionResponseDTO.self
        )
    }

    func leaveSession(
        code: ShareCode,
        sessionToken: String
    ) async throws(CollaborationError) {
        let url = baseURL.appendingPathComponent("v1/shared-sessions/\(code.value)/leave")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(sessionToken, forHTTPHeaderField: "x-session-token")
        let (data, http) = try await performDataRequest(request)
        try validateStatus(http.statusCode, data: data)
    }

    func closeSession(
        code: ShareCode,
        sessionToken: String
    ) async throws(CollaborationError) {
        let url = baseURL.appendingPathComponent("v1/shared-sessions/\(code.value)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(sessionToken, forHTTPHeaderField: "x-session-token")
        let (data, http) = try await performDataRequest(request)
        try validateStatus(http.statusCode, data: data)
    }

    func streamEvents(
        code: ShareCode,
        sessionToken: String
    ) -> AsyncThrowingStream<CollaborationSSEEventDTO, Error> {
        let url = baseURL.appendingPathComponent("v1/shared-sessions/\(code.value)/events")
        let capturedSession = session

        return AsyncThrowingStream { continuation in
            let task = Task {
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                request.setValue(sessionToken, forHTTPHeaderField: "x-session-token")

                do {
                    let (bytes, response) = try await capturedSession.bytes(for: request)
                    guard let http = response as? HTTPURLResponse,
                          (200...299).contains(http.statusCode) else {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
                        continuation.finish(throwing: CollaborationError.serverError(
                            statusCode: statusCode,
                            message: "SSE connection failed"
                        ))
                        return
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        guard line.hasPrefix("data:") else { continue }
                        let jsonPart = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        guard let jsonData = jsonPart.data(using: .utf8),
                              let event = try? JSONDecoder().decode(CollaborationSSEEventDTO.self, from: jsonData) else {
                            continue
                        }
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    if !Task.isCancelled {
                        continuation.finish(throwing: error)
                    } else {
                        continuation.finish()
                    }
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Helpers

    private func sendJSONRequest<Body: Encodable, Response: Decodable>(
        url: URL,
        method: String,
        body: Body,
        sessionToken: String?,
        responseType: Response.Type
    ) async throws(CollaborationError) -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let sessionToken {
            request.setValue(sessionToken, forHTTPHeaderField: "x-session-token")
        }

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw .decodingFailed
        }

        let (data, http) = try await performDataRequest(request)
        try validateStatus(http.statusCode, data: data)

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw .decodingFailed
        }
    }

    private func performDataRequest(_ request: URLRequest) async throws(CollaborationError) -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .networkUnavailable
        }
        guard let http = response as? HTTPURLResponse else {
            throw .networkUnavailable
        }
        return (data, http)
    }

    private func validateStatus(_ statusCode: Int, data: Data) throws(CollaborationError) {
        guard !(200...299).contains(statusCode) else { return }

        switch statusCode {
        case 401:
            throw .unauthorized
        case 403:
            let message = String(data: data, encoding: .utf8) ?? ""
            if message.localizedCaseInsensitiveContains("quarantine") {
                throw .sessionQuarantined
            }
            throw .forbidden(message)
        case 404:
            throw .sessionNotFound
        case 409:
            let payload = try? JSONDecoder().decode(ConflictServerPayloadDTO.self, from: data)
            throw .versionConflict(serverVersion: payload?.serverVersion ?? 0)
        case 410:
            throw .sessionExpired
        case 429:
            throw .rateLimited
        default:
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(statusCode)"
            throw .serverError(statusCode: statusCode, message: message)
        }
    }
}
