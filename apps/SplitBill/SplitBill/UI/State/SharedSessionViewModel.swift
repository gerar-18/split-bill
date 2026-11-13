import Foundation
import Observation
import UIKit

/// Presentation state orchestrating live collaborative sessions (Host QR sharing, Guest join,
/// real-time SSE reconciliation, optimistic claim toggles, and Apple Guideline 1.2 moderation).
@Observable
@MainActor
final class SharedSessionViewModel {

    // MARK: - Dependencies

    private let service: any CollaborationServicing
    private let stateStore: any CollaborationStateStoring
    private var sseTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?

    // MARK: - Presentation & Sheet State

    var isShowingShareSheet: Bool = false
    var isShowingJoinSheet: Bool = false
    var isShowingLiveSessionSheet: Bool = false
    var isShowingReportSheet: Bool = false
    var prefilledJoinCode: String = ""

    // MARK: - Active Session State

    private(set) var activeSnapshot: CollaborationSnapshotDTO?
    private(set) var activeShareCode: ShareCode?
    private(set) var sessionToken: String?
    private(set) var myParticipantID: UUID?
    private(set) var isHost: Bool = false
    private(set) var domainParticipants: [Participant] = []
    private(set) var domainItems: [SharedReceiptLineItem] = []
    private(set) var domainPreview: CollaborationSplitPreview?

    // MARK: - UI Feedback State

    private(set) var isLoading: Bool = false
    private(set) var isMutatingClaim: Bool = false
    private(set) var isImageHiddenLocally: Bool = false
    var errorMessage: String?
    var statusBanner: String?

    var shareURL: URL? {
        guard let code = activeShareCode else { return nil }
        return URL(string: "splitbill://join?code=\(code.value)")
    }

    var universalShareURL: URL? {
        guard let code = activeShareCode else { return nil }
        return URL(string: "https://splitbill.app/join?code=\(code.value)")
    }

    var shouldDisplayReceiptImage: Bool {
        guard let snapshot = activeSnapshot else { return false }
        guard snapshot.includeImage,
              !snapshot.imageHiddenByModeration,
              snapshot.domainStatus != .quarantined,
              !isImageHiddenLocally,
              snapshot.imageBase64OptIn != nil else {
            return false
        }
        return true
    }

    var decodedOptInImage: UIImage? {
        guard shouldDisplayReceiptImage,
              let base64 = activeSnapshot?.imageBase64OptIn,
              let data = Data(base64Encoded: base64) else {
            return nil
        }
        return UIImage(data: data)
    }

    init(
        service: any CollaborationServicing = HTTPCollaborationService(),
        stateStore: any CollaborationStateStoring = KeychainCollaborationStateStore()
    ) {
        self.service = service
        self.stateStore = stateStore
    }

    // MARK: - Host Workflow

    /// Publishes the current local receipt into a live collaborative session.
    /// Photo upload is opt-in and defaults to `false` (Option A privacy-first).
    func publishSession(
        from editor: ReceiptEditorViewModel,
        hostDisplayName: String,
        includeImage: Bool
    ) async {
        let trimmedHost = hostDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty else {
            errorMessage = "Ingresa tu nombre para identificar al anfitrión."
            return
        }

        let trimmedTitle = editor.receiptTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = trimmedTitle.isEmpty ? "Cuenta Compartida" : trimmedTitle

        isLoading = true
        errorMessage = nil
        statusBanner = nil

        let isoFormatter = ISO8601DateFormatter()
        let nowISO = isoFormatter.string(from: Date())

        let itemInputs = editor.items.map { item in
            CollaborationReceiptItemInputDTO(
                id: item.id.uuidString.lowercased(),
                name: item.name,
                quantity: item.quantity,
                priceCents: item.unitPrice.amountInMinorUnits
            )
        }
        let participantInputs = editor.participants.map { participant in
            CollaborationReceiptParticipantInputDTO(
                id: participant.id.uuidString.lowercased(),
                name: participant.name
            )
        }

        let receiptInput = CollaborationReceiptInputDTO(
            title: title,
            date: nowISO,
            currency: editor.currency.code,
            subtotalCents: editor.itemsSubtotal.amountInMinorUnits,
            taxCents: editor.resolvedTax.amountInMinorUnits,
            tipCents: editor.resolvedTip.amountInMinorUnits,
            totalCents: editor.grandTotal.amountInMinorUnits,
            clientCreatedAt: nowISO,
            clientUpdatedAt: nowISO,
            items: itemInputs,
            participants: participantInputs
        )

        var optInBase64: String?
        if includeImage,
           let rawData = editor.receiptImageData,
           let image = UIImage(data: rawData),
           let compressed = ReceiptImageProcessor.process(image, maxDimension: 1200, compressionQuality: 0.65) {
            optInBase64 = compressed.base64EncodedString()
        }

        let request = CreateSharedSessionRequestDTO(
            receipt: receiptInput,
            hostDisplayName: trimmedHost,
            includeImage: includeImage && optInBase64 != nil,
            imageBase64OptIn: optInBase64
        )

        do {
            let response = try await service.createSession(request)
            let code = try ShareCode(rawValue: response.shareCode)
            applySessionActivation(
                code: code,
                token: response.sessionToken,
                participantIDString: response.participantId,
                isHost: true,
                snapshot: response.snapshot
            )
            isLoading = false
        } catch let err as CollaborationError {
            isLoading = false
            errorMessage = readableError(err)
        } catch let domainErr as DomainError {
            isLoading = false
            errorMessage = domainErr == .invalidShareCode ? "Código inválido recibido del servidor." : "Error de dominio."
        } catch {
            isLoading = false
            errorMessage = "No se pudo crear la sesión compartida."
        }
    }

    func closeActiveSession() async {
        guard let code = activeShareCode, let token = sessionToken, isHost else {
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            try await service.closeSession(code: code, sessionToken: token)
            stateStore.deleteSessionToken(forShareCode: code.value)
            resetSessionState()
            isShowingShareSheet = false
            isShowingLiveSessionSheet = false
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = readableError(error)
        }
    }

    // MARK: - Guest Join & Live Sync

    func joinSession(rawCode: String, displayName: String) async {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Ingresa tu nombre para unirte a la cuenta."
            return
        }

        let code: ShareCode
        do {
            code = try ShareCode(rawValue: rawCode)
        } catch {
            errorMessage = "El código debe tener 8 caracteres válidos (sin I, L, O o U)."
            return
        }

        guard !stateStore.isSessionBlocked(sessionIDOrCode: code.value) else {
            errorMessage = "Bloqueaste esta sesión anteriormente."
            return
        }

        isLoading = true
        errorMessage = nil
        statusBanner = nil

        do {
            let response = try await service.joinSession(code: code, displayName: trimmedName)
            guard !stateStore.isSessionBlocked(sessionIDOrCode: response.snapshot.sessionId) else {
                isLoading = false
                errorMessage = "Bloqueaste esta sesión anteriormente."
                return
            }

            applySessionActivation(
                code: code,
                token: response.sessionToken,
                participantIDString: response.participantId,
                isHost: false,
                snapshot: response.snapshot
            )
            isLoading = false
            isShowingJoinSheet = false
            isShowingLiveSessionSheet = true
        } catch {
            isLoading = false
            errorMessage = readableError(error)
        }
    }

    func toggleClaim(forItemID itemId: UUID) async {
        guard let code = activeShareCode,
              let token = sessionToken,
              let myID = myParticipantID,
              let snapshot = activeSnapshot else {
            return
        }
        guard snapshot.domainStatus == .active else {
            errorMessage = "La sesión ya no acepta cambios."
            return
        }

        let itemMatches = domainItems.first(where: { $0.id == itemId })
        let currentlyClaimed = itemMatches?.claimantIDs.contains(myID) ?? false
        let action: ClaimAction = currentlyClaimed ? .unclaim : .claim

        isMutatingClaim = true
        errorMessage = nil

        do {
            let updated = try await service.toggleClaim(
                code: code,
                sessionToken: token,
                itemId: itemId,
                action: action,
                expectedVersion: snapshot.version
            )
            applySnapshot(updated)
            isMutatingClaim = false
        } catch CollaborationError.versionConflict {
            // Reconcile automatically with server state and notify user to tap again if needed
            statusBanner = "Otro invitado actualizó la cuenta; sincronizando cambios…"
            await refreshSnapshot()
            isMutatingClaim = false
        } catch {
            isMutatingClaim = false
            errorMessage = readableError(error)
        }
    }

    func refreshSnapshot() async {
        guard let code = activeShareCode, let token = sessionToken else { return }
        let expectedCode = code.value

        do {
            if let fresh = try await service.fetchSnapshot(
                code: code,
                sessionToken: token,
                sinceVersion: activeSnapshot?.version
            ) {
                guard activeShareCode?.value == expectedCode else { return }
                applySnapshot(fresh)
            }
        } catch CollaborationError.sessionExpired {
            statusBanner = "La sesión expiró o fue cerrada por el anfitrión."
            stopStreams()
        } catch CollaborationError.sessionQuarantined {
            statusBanner = "Sesión bloqueada por reportes de moderación."
            stopStreams()
        } catch {
            // Transient fetch failure should not interrupt active screen
        }
    }

    // MARK: - Moderation & Block Controls (Guideline 1.2)

    func hideImageLocally() {
        isImageHiddenLocally = true
        if let sessionID = activeSnapshot?.sessionId {
            stateStore.setImageHidden(true, forSessionID: sessionID)
        }
    }

    func submitReport(reason: ModerationReportReason, note: String?) async {
        guard let code = activeShareCode, let token = sessionToken else { return }
        isLoading = true
        errorMessage = nil
        do {
            let result = try await service.reportSession(
                code: code,
                sessionToken: token,
                reason: reason,
                note: note
            )
            isLoading = false
            isShowingReportSheet = false
            if result.quarantined {
                statusBanner = "La sesión fue puesta en cuarentena por reportes."
                isImageHiddenLocally = true
                await refreshSnapshot()
            } else {
                statusBanner = "Reporte enviado. Gracias por mantener SplitBill seguro."
            }
        } catch {
            isLoading = false
            errorMessage = readableError(error)
        }
    }

    func blockAndLeaveSession() async {
        guard let code = activeShareCode else {
            resetSessionState()
            isShowingLiveSessionSheet = false
            return
        }
        let sessionId = activeSnapshot?.sessionId
        let token = sessionToken

        if let sessionId {
            stateStore.blockSession(sessionIDOrCode: sessionId)
        }
        stateStore.blockSession(sessionIDOrCode: code.value)
        stateStore.deleteSessionToken(forShareCode: code.value)

        if let token, !isHost {
            try? await service.leaveSession(code: code, sessionToken: token)
        }

        resetSessionState()
        isShowingLiveSessionSheet = false
        isShowingShareSheet = false
    }

    func stopStreams() {
        sseTask?.cancel()
        sseTask = nil
        pollingTask?.cancel()
        pollingTask = nil
    }

    func openJoinFlow(prefilledCode: String? = nil) {
        errorMessage = nil
        if let prefilledCode {
            if stateStore.isSessionBlocked(sessionIDOrCode: prefilledCode) {
                errorMessage = "Bloqueaste esta sesión anteriormente."
                return
            }
            prefilledJoinCode = prefilledCode
        }
        isShowingJoinSheet = true
    }

    // MARK: - Private Synchronization Helpers

    private func applySessionActivation(
        code: ShareCode,
        token: String,
        participantIDString: String,
        isHost: Bool,
        snapshot: CollaborationSnapshotDTO
    ) {
        self.activeShareCode = code
        self.sessionToken = token
        self.myParticipantID = UUID(uuidString: participantIDString)
        self.isHost = isHost
        self.stateStore.saveSessionToken(token, forShareCode: code.value)
        self.isImageHiddenLocally = stateStore.isImageHidden(forSessionID: snapshot.sessionId)
        applySnapshot(snapshot)
        startLiveSyncLoop(for: code, token: token)
    }

    private func applySnapshot(_ snapshot: CollaborationSnapshotDTO) {
        self.activeSnapshot = snapshot
        if stateStore.isImageHidden(forSessionID: snapshot.sessionId) || snapshot.imageHiddenByModeration {
            self.isImageHiddenLocally = true
        }
        if snapshot.domainStatus == .quarantined {
            statusBanner = "Contenido oculto: sesión puesta en cuarentena."
        } else if snapshot.domainStatus == .closed {
            statusBanner = "El anfitrión cerró esta sesión compartida."
        }

        do {
            let domain = try snapshot.toDomainPreview()
            self.domainParticipants = domain.participants
            self.domainItems = domain.items
            self.domainPreview = domain.preview
        } catch {
            self.errorMessage = "No se pudo reconciliar el cálculo de la sesión."
        }
    }

    private func startLiveSyncLoop(for code: ShareCode, token: String) {
        stopStreams()
        let expectedCode = code.value

        sseTask = Task { [weak self] in
            guard let self else { return }
            let stream = self.service.streamEvents(code: code, sessionToken: token)
            do {
                for try await event in stream {
                    if Task.isCancelled { break }
                    guard self.activeShareCode?.value == expectedCode else { break }

                    if event.eventType == "session_closed" {
                        self.statusBanner = "El anfitrión cerró esta sesión."
                        await self.refreshSnapshot()
                        break
                    } else if event.eventType == "session_quarantined" {
                        self.isImageHiddenLocally = true
                        self.statusBanner = "Sesión bloqueada por reportes de moderación."
                        await self.refreshSnapshot()
                        break
                    } else if event.version > (self.activeSnapshot?.version ?? 0) {
                        await self.refreshSnapshot()
                    }
                }
            } catch {
                // SSE dropped — lightweight versioned fallback poll catches up gracefully
                if !Task.isCancelled && self.activeShareCode?.value == expectedCode {
                    self.startFallbackPolling(for: code)
                }
            }
        }
    }

    private func startFallbackPolling(for code: ShareCode) {
        pollingTask?.cancel()
        let expectedCode = code.value
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self, !Task.isCancelled, self.activeShareCode?.value == expectedCode else { break }
                await self.refreshSnapshot()
            }
        }
    }

    private func resetSessionState() {
        stopStreams()
        activeSnapshot = nil
        activeShareCode = nil
        sessionToken = nil
        myParticipantID = nil
        isHost = false
        domainParticipants = []
        domainItems = []
        domainPreview = nil
        isImageHiddenLocally = false
        statusBanner = nil
    }

    private func readableError(_ error: CollaborationError) -> String {
        switch error {
        case .invalidURL:
            return "URL de colaboración inválida."
        case .invalidShareCode:
            return "Código inválido. Debe tener 8 caracteres."
        case .networkUnavailable:
            return "No hay conexión con el servidor de colaboración."
        case .sessionNotFound:
            return "No encontramos ninguna sesión activa con ese código."
        case .sessionExpired:
            return "Esta sesión ya expiró o fue cerrada."
        case .sessionQuarantined:
            return "Esta sesión fue suspendida por reportes de contenido inapropiado."
        case .versionConflict:
            return "La cuenta cambió en otro dispositivo. Sincronizando…"
        case .unauthorized:
            return "Tu acceso a esta sesión expiró o fue revocado."
        case .forbidden(let msg):
            return msg.isEmpty ? "No tienes permiso para realizar esta acción." : msg
        case .rateLimited:
            return "Demasiados intentos seguidos. Espera un minuto."
        case .serverError(_, let msg):
            return "Error del servidor: \(msg)"
        case .decodingFailed:
            return "Respuesta inesperada del servidor."
        }
    }
}
