import Foundation
import Testing
import UIKit
@testable import SplitBill

nonisolated final class MockCollaborationService: CollaborationServicing, @unchecked Sendable {
    private let lock = NSLock()
    var lastCreateRequest: CreateSharedSessionRequestDTO?
    var snapshotToReturn: CollaborationSnapshotDTO
    var claimResultQueue: [Result<CollaborationSnapshotDTO, CollaborationError>] = []
    var didCloseSession = false
    var didLeaveSession = false
    var lastReportReason: ModerationReportReason?

    init(snapshot: CollaborationSnapshotDTO? = nil) {
        let p1 = "11111111-1111-4111-8111-111111111111"
        let i1 = "22222222-2222-4222-8222-222222222222"
        self.snapshotToReturn = snapshot ?? CollaborationSnapshotDTO(
            sessionId: "sess-mock-1",
            shareCode: "ABCD2345",
            status: "ACTIVE",
            version: 1,
            includeImage: false,
            imageHiddenByModeration: false,
            imageBase64OptIn: nil,
            reportCount: 0,
            expiresAt: "2026-11-13T22:00:00.000Z",
            receipt: CollaborationReceiptSnapshotDTO(
                id: "33333333-3333-4333-8333-333333333333",
                title: "Cena",
                date: "2026-11-12T22:00:00.000Z",
                currency: "MXN",
                subtotalCents: 1000,
                taxCents: 160,
                tipCents: 100,
                totalCents: 1260,
                items: [
                    CollaborationItemSnapshotDTO(
                        id: i1,
                        name: "Tacos",
                        quantity: 1,
                        priceCents: 1000,
                        claimantIds: []
                    )
                ],
                participants: [
                    CollaborationParticipantSnapshotDTO(id: p1, name: "Gera", isHost: true)
                ]
            )
        )
    }

    func createSession(
        _ request: CreateSharedSessionRequestDTO
    ) async throws(CollaborationError) -> CreateOrJoinSessionResponseDTO {
        lock.withLock { lastCreateRequest = request }
        return CreateOrJoinSessionResponseDTO(
            shareCode: "ABCD2345",
            sessionToken: "host-token-xyz",
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
            sessionToken: "guest-token-xyz",
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
        let nextResult = lock.withLock {
            claimResultQueue.isEmpty ? nil : claimResultQueue.removeFirst()
        }
        if let nextResult {
            return try nextResult.get()
        }
        return snapshotToReturn
    }

    func reportSession(
        code: ShareCode,
        sessionToken: String,
        reason: ModerationReportReason,
        note: String?
    ) async throws(CollaborationError) -> ReportSessionResponseDTO {
        lock.withLock { lastReportReason = reason }
        return ReportSessionResponseDTO(reported: true, quarantined: false, reportCount: 1)
    }

    func leaveSession(code: ShareCode, sessionToken: String) async throws(CollaborationError) {
        lock.withLock { didLeaveSession = true }
    }

    func closeSession(code: ShareCode, sessionToken: String) async throws(CollaborationError) {
        lock.withLock { didCloseSession = true }
    }

    func streamEvents(
        code: ShareCode,
        sessionToken: String
    ) -> AsyncThrowingStream<CollaborationSSEEventDTO, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}

@Suite("SharedSessionViewModel & QR Generator Tests")
@MainActor
struct SharedSessionViewModelTests {

    @Test("QRCodeGenerator produces crisp image for splitbill deep link")
    func qrCodeGeneration() {
        let image = QRCodeGenerator.generate(from: "splitbill://join?code=ABCD2345", dimension: 200)
        #expect(image != nil)
        #expect((image?.size.width ?? 0) >= 100)
    }

    @Test("Publishing session excludes receipt photo by default (Option A privacy-first)")
    func publishDefaultsToExcludingImage() async throws {
        let editor = ReceiptEditorViewModel(store: nil)
        editor.receiptTitle = "Tacos"
        let p = try Participant(name: "Gera")
        editor.participants = [p]
        editor.items = [
            try ReceiptItem(
                name: "Tacos",
                unitPrice: Money(amountInMinorUnits: 1000, currency: .mxn),
                quantity: 1,
                splitMode: .wholeItem(p.id)
            )
        ]
        // Attach sample receipt image locally
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        let sampleImg = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        editor.receiptImageData = sampleImg.jpegData(compressionQuality: 0.8)

        let mockService = MockCollaborationService()
        let stateStore = InMemoryCollaborationStateStore()
        let vm = SharedSessionViewModel(service: mockService, stateStore: stateStore)

        await vm.publishSession(from: editor, hostDisplayName: "Gera", includeImage: false)

        #expect(vm.activeShareCode?.value == "ABCD2345")
        #expect(vm.isHost == true)
        #expect(mockService.lastCreateRequest?.includeImage == false)
        #expect(mockService.lastCreateRequest?.imageBase64OptIn == nil)
        #expect(stateStore.loadSessionToken(forShareCode: "ABCD2345") == "host-token-xyz")
    }

    @Test("Closing active session clears token and resets active snapshot")
    func closeSessionResetsState() async throws {
        let editor = ReceiptEditorViewModel(store: nil)
        let p = try Participant(name: "Gera")
        editor.participants = [p]
        editor.items = [
            try ReceiptItem(
                name: "Agua",
                unitPrice: Money(amountInMinorUnits: 500, currency: .mxn),
                quantity: 1,
                splitMode: .wholeItem(p.id)
            )
        ]

        let mockService = MockCollaborationService()
        let stateStore = InMemoryCollaborationStateStore()
        let vm = SharedSessionViewModel(service: mockService, stateStore: stateStore)

        await vm.publishSession(from: editor, hostDisplayName: "Gera", includeImage: false)
        await vm.closeActiveSession()

        #expect(mockService.didCloseSession == true)
        #expect(vm.activeSnapshot == nil)
        #expect(stateStore.loadSessionToken(forShareCode: "ABCD2345") == nil)
    }

    @Test("Version conflict on claim toggle refreshes snapshot from server cleanly")
    func versionConflictTriggersAutoReconcile() async throws {
        let mockService = MockCollaborationService()
        let stateStore = InMemoryCollaborationStateStore()
        let vm = SharedSessionViewModel(service: mockService, stateStore: stateStore)

        let code = try ShareCode(rawValue: "ABCD2345")
        await vm.joinSession(rawCode: code.value, displayName: "Ana")

        mockService.claimResultQueue = [.failure(.versionConflict(serverVersion: 4))]
        let itemUUID = try #require(UUID(uuidString: "22222222-2222-4222-8222-222222222222"))
        await vm.toggleClaim(forItemID: itemUUID)

        #expect(vm.statusBanner?.contains("sincronizando") == true)
    }
}
