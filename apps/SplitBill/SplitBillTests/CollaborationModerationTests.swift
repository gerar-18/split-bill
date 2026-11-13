import Foundation
import Testing
import UIKit
@testable import SplitBill

private nonisolated final class ModerationMockService: CollaborationServicing, @unchecked Sendable {
    var snapshotToReturn: CollaborationSnapshotDTO
    var reportQuarantined = false
    var recordedReasons: [ModerationReportReason] = []
    var recordedNotes: [String?] = []
    var didCallLeaveSession = false

    init(snapshot: CollaborationSnapshotDTO) {
        self.snapshotToReturn = snapshot
    }

    func createSession(
        _ request: CreateSharedSessionRequestDTO
    ) async throws(CollaborationError) -> CreateOrJoinSessionResponseDTO {
        CreateOrJoinSessionResponseDTO(
            shareCode: snapshotToReturn.shareCode,
            sessionToken: "host-tok",
            participantId: "11111111-1111-4111-8111-111111111111",
            snapshot: snapshotToReturn
        )
    }

    func joinSession(
        code: ShareCode,
        displayName: String
    ) async throws(CollaborationError) -> CreateOrJoinSessionResponseDTO {
        CreateOrJoinSessionResponseDTO(
            shareCode: code.value,
            sessionToken: "guest-tok",
            participantId: "44444444-4444-4444-8444-444444444444",
            snapshot: snapshotToReturn
        )
    }

    func fetchSnapshot(
        code: ShareCode,
        sessionToken: String,
        sinceVersion: Int?
    ) async throws(CollaborationError) -> CollaborationSnapshotDTO? {
        snapshotToReturn
    }

    func toggleClaim(
        code: ShareCode,
        sessionToken: String,
        itemId: UUID,
        action: ClaimAction,
        expectedVersion: Int
    ) async throws(CollaborationError) -> CollaborationSnapshotDTO {
        snapshotToReturn
    }

    func reportSession(
        code: ShareCode,
        sessionToken: String,
        reason: ModerationReportReason,
        note: String?
    ) async throws(CollaborationError) -> ReportSessionResponseDTO {
        recordedReasons.append(reason)
        recordedNotes.append(note)
        return ReportSessionResponseDTO(
            reported: true,
            quarantined: reportQuarantined,
            reportCount: reportQuarantined ? 3 : 1
        )
    }

    func leaveSession(code: ShareCode, sessionToken: String) async throws(CollaborationError) {
        didCallLeaveSession = true
    }

    func closeSession(code: ShareCode, sessionToken: String) async throws(CollaborationError) {}

    func streamEvents(
        code: ShareCode,
        sessionToken: String
    ) -> AsyncThrowingStream<CollaborationSSEEventDTO, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}

@Suite("Collaboration UGC Moderation Tests (Guideline 1.2)")
@MainActor
struct CollaborationModerationTests {

    private func makeSnapshot(
        status: String = "ACTIVE",
        includeImage: Bool = true,
        imageHiddenByModeration: Bool = false
    ) -> CollaborationSnapshotDTO {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        let pngData = renderer.pngData { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        return CollaborationSnapshotDTO(
            sessionId: "sess-mod-1",
            shareCode: "MD892345",
            status: status,
            version: 1,
            includeImage: includeImage,
            imageHiddenByModeration: imageHiddenByModeration,
            imageBase64OptIn: includeImage ? pngData.base64EncodedString() : nil,
            reportCount: status == "QUARANTINED" ? 3 : 0,
            expiresAt: "2026-11-14T00:00:00.000Z",
            receipt: CollaborationReceiptSnapshotDTO(
                id: "33333333-3333-4333-8333-333333333333",
                title: "Mesa 4",
                date: "2026-11-12T22:00:00.000Z",
                currency: "MXN",
                subtotalCents: 500,
                taxCents: 0,
                tipCents: 0,
                totalCents: 500,
                items: [
                    CollaborationItemSnapshotDTO(
                        id: "22222222-2222-4222-8222-222222222222",
                        name: "Agua",
                        quantity: 1,
                        priceCents: 500,
                        claimantIds: []
                    )
                ],
                participants: [
                    CollaborationParticipantSnapshotDTO(
                        id: "11111111-1111-4111-8111-111111111111",
                        name: "Host",
                        isHost: true
                    )
                ]
            )
        )
    }

    @Test("Hiding opt-in image locally immediately suppresses display and persists preference")
    func hideImageLocallySuppressesDisplay() async {
        let service = ModerationMockService(snapshot: makeSnapshot())
        let store = InMemoryCollaborationStateStore()
        let vm = SharedSessionViewModel(service: service, stateStore: store)

        await vm.joinSession(rawCode: "MD892345", displayName: "Invitado")
        #expect(vm.shouldDisplayReceiptImage == true)
        #expect(vm.decodedOptInImage != nil)

        vm.hideImageLocally()
        #expect(vm.shouldDisplayReceiptImage == false)
        #expect(vm.decodedOptInImage == nil)
        #expect(store.isImageHidden(forSessionID: "sess-mod-1") == true)
    }

    @Test("Quarantined report hides content and refreshes snapshot")
    func quarantinedReportHidesContent() async {
        let activeSnapshot = makeSnapshot()
        let quarantinedSnapshot = makeSnapshot(status: "QUARANTINED", imageHiddenByModeration: true)
        let service = ModerationMockService(snapshot: activeSnapshot)
        let store = InMemoryCollaborationStateStore()
        let vm = SharedSessionViewModel(service: service, stateStore: store)

        await vm.joinSession(rawCode: "MD892345", displayName: "Invitado")
        service.reportQuarantined = true
        service.snapshotToReturn = quarantinedSnapshot

        await vm.submitReport(reason: .inappropriateImage, note: "Contenido ofensivo")

        #expect(service.recordedReasons == [.inappropriateImage])
        #expect(service.recordedNotes == ["Contenido ofensivo"])
        #expect(vm.isImageHiddenLocally == true)
        #expect(vm.shouldDisplayReceiptImage == false)
        #expect(vm.activeSnapshot?.domainStatus == .quarantined)
    }

    @Test("Block and leave revokes local token, notifies backend, and blocks future deep links")
    func blockAndLeavePreventsReentry() async throws {
        let service = ModerationMockService(snapshot: makeSnapshot())
        let store = InMemoryCollaborationStateStore()
        let vm = SharedSessionViewModel(service: service, stateStore: store)

        await vm.joinSession(rawCode: "MD892345", displayName: "Invitado")
        #expect(store.loadSessionToken(forShareCode: "MD892345") == "guest-tok")

        await vm.blockAndLeaveSession()

        #expect(service.didCallLeaveSession == true)
        #expect(vm.activeSnapshot == nil)
        #expect(vm.isShowingLiveSessionSheet == false)
        #expect(store.loadSessionToken(forShareCode: "MD892345") == nil)
        #expect(store.isSessionBlocked(sessionIDOrCode: "MD892345") == true)
        #expect(store.isSessionBlocked(sessionIDOrCode: "sess-mod-1") == true)

        let incomingURL = try #require(URL(string: "splitbill://join?code=MD892345"))
        vm.handleIncomingURL(incomingURL)
        #expect(vm.isShowingJoinSheet == false)
        #expect(vm.errorMessage != nil)
    }
}
