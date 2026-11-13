import Foundation

/// Typed errors produced by the live collaboration client layer.
nonisolated enum CollaborationError: Error, Equatable, Sendable {
    case invalidURL
    case invalidShareCode
    case networkUnavailable
    case sessionNotFound
    case sessionExpired
    case sessionQuarantined
    case versionConflict(serverVersion: Int)
    case unauthorized
    case forbidden(String)
    case rateLimited
    case serverError(statusCode: Int, message: String)
    case decodingFailed
}

nonisolated enum ClaimAction: String, Codable, Sendable {
    case claim
    case unclaim
}

// MARK: - Request DTOs

nonisolated struct CollaborationReceiptItemInputDTO: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let quantity: Int
    let priceCents: Int64
}

nonisolated struct CollaborationReceiptParticipantInputDTO: Codable, Equatable, Sendable {
    let id: String
    let name: String
}

nonisolated struct CollaborationReceiptInputDTO: Codable, Equatable, Sendable {
    let title: String
    let date: String
    let currency: String
    let subtotalCents: Int64
    let taxCents: Int64
    let tipCents: Int64
    let totalCents: Int64
    let clientCreatedAt: String
    let clientUpdatedAt: String
    let items: [CollaborationReceiptItemInputDTO]
    let participants: [CollaborationReceiptParticipantInputDTO]
}

nonisolated struct CreateSharedSessionRequestDTO: Codable, Equatable, Sendable {
    let receipt: CollaborationReceiptInputDTO
    let hostDisplayName: String
    let includeImage: Bool
    let imageBase64OptIn: String?
}

nonisolated struct JoinSharedSessionRequestDTO: Codable, Equatable, Sendable {
    let displayName: String
}

nonisolated struct ToggleClaimRequestDTO: Codable, Equatable, Sendable {
    let itemId: String
    let action: String
    let expectedVersion: Int
}

nonisolated struct ReportSessionRequestDTO: Codable, Equatable, Sendable {
    let reason: String
    let note: String?
}

// MARK: - Response DTOs

nonisolated struct CollaborationItemSnapshotDTO: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let name: String
    let quantity: Int
    let priceCents: Int64
    let claimantIds: [String]
}

nonisolated struct CollaborationParticipantSnapshotDTO: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let name: String
    let isHost: Bool
}

nonisolated struct CollaborationReceiptSnapshotDTO: Codable, Equatable, Sendable {
    let id: String
    let title: String
    let date: String
    let currency: String
    let subtotalCents: Int64
    let taxCents: Int64
    let tipCents: Int64
    let totalCents: Int64
    let items: [CollaborationItemSnapshotDTO]
    let participants: [CollaborationParticipantSnapshotDTO]
}

nonisolated struct CollaborationSnapshotDTO: Codable, Equatable, Sendable {
    let sessionId: String
    let shareCode: String
    let status: String
    let version: Int
    let includeImage: Bool
    let imageHiddenByModeration: Bool
    let imageBase64OptIn: String?
    let reportCount: Int
    let expiresAt: String
    let receipt: CollaborationReceiptSnapshotDTO

    var domainStatus: SharedSessionStatus {
        switch status.uppercased() {
        case "ACTIVE": return .active
        case "CLOSED": return .closed
        case "QUARANTINED": return .quarantined
        default: return .expired
        }
    }

    /// Converts the network DTO into pure Domain models + `CollaborationSplitPreview`.
    func toDomainPreview() throws -> (
        participants: [Participant],
        items: [SharedReceiptLineItem],
        preview: CollaborationSplitPreview
    ) {
        let currency = Currency(code: receipt.currency, minorUnitScale: 2)
        let domainParticipants: [Participant] = try receipt.participants.compactMap { dto in
            guard let uuid = UUID(uuidString: dto.id) else { return nil }
            return try Participant(id: uuid, name: dto.name)
        }

        let domainItems: [SharedReceiptLineItem] = try receipt.items.compactMap { itemDto in
            guard let itemUUID = UUID(uuidString: itemDto.id) else { return nil }
            let claimantUUIDs = itemDto.claimantIds.compactMap(UUID.init(uuidString:))
            return try SharedReceiptLineItem(
                id: itemUUID,
                name: itemDto.name,
                unitPrice: Money(amountInMinorUnits: itemDto.priceCents, currency: currency),
                quantity: itemDto.quantity,
                claimantIDs: claimantUUIDs
            )
        }

        let receiptUUID = UUID(uuidString: receipt.id) ?? UUID()
        let preview = try CollaborationSplitPreview.compute(
            receiptID: receiptUUID,
            currency: currency,
            participants: domainParticipants,
            items: domainItems,
            tax: Money(amountInMinorUnits: receipt.taxCents, currency: currency),
            tip: Money(amountInMinorUnits: receipt.tipCents, currency: currency)
        )

        return (domainParticipants, domainItems, preview)
    }
}

nonisolated struct CollaborationUnchangedDTO: Codable, Equatable, Sendable {
    let unchanged: Bool
    let version: Int
    let status: String
}

nonisolated struct CreateOrJoinSessionResponseDTO: Codable, Equatable, Sendable {
    let shareCode: String
    let sessionToken: String
    let participantId: String
    let snapshot: CollaborationSnapshotDTO
}

nonisolated struct ReportSessionResponseDTO: Codable, Equatable, Sendable {
    let reported: Bool
    let quarantined: Bool
    let reportCount: Int
}

nonisolated struct CollaborationSSEEventDTO: Codable, Equatable, Sendable {
    let shareCode: String
    let version: Int
    let status: String
    let eventType: String
}

nonisolated struct ConflictServerPayloadDTO: Codable, Sendable {
    let serverVersion: Int?
    let message: String?
}
