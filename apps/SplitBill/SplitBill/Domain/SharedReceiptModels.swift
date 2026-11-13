import Foundation

/// Validated 8-character Crockford Base32 share code used to join a live collaborative receipt.
/// Excludes ambiguous letters (`I`, `L`, `O`, `U`) to make manual entry reliable.
nonisolated struct ShareCode: Equatable, Hashable, Sendable, Codable {
    static let expectedLength = 8
    private static let allowedAlphabet: Set<Character> = Set("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    let value: String

    init(rawValue: String) throws(DomainError) {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard normalized.count == Self.expectedLength,
              normalized.allSatisfy({ Self.allowedAlphabet.contains($0) }) else {
            throw .invalidShareCode
        }

        self.value = normalized
    }
}

/// Lifecycle status of a collaborative receipt session.
nonisolated enum SharedSessionStatus: String, Equatable, Sendable, Codable {
    case active
    case closed
    case quarantined
    case expired
}

/// Supported Apple Guideline 1.2 moderation report categories for shared receipts.
nonisolated enum ModerationReportReason: String, CaseIterable, Equatable, Sendable, Codable, Identifiable {
    case inappropriateImage = "INAPPROPRIATE_IMAGE"
    case spamOrScam = "SPAM_OR_SCAM"
    case harassmentOrOffensiveText = "HARASSMENT_OR_OFFENSIVE_TEXT"
    case other = "OTHER"

    var id: String { rawValue }
}

/// Additive claim state of a collaborative line item.
/// Keeps `SplitMode` strict (`>= 1` claimant) while representing temporarily unassigned items explicitly.
nonisolated enum SharedItemClaimState: Equatable, Sendable {
    case unassigned
    case assigned(SplitMode)

    /// Maps an array of claimant IDs into a deterministic domain claim state:
    /// - 0 claimants -> `.unassigned`
    /// - 1 claimant  -> `.assigned(.wholeItem)`
    /// - 2+ claimants -> `.assigned(.equal)`
    static func fromClaimants(
        _ claimantIDs: [Participant.ID],
        validParticipants: Set<Participant.ID>
    ) throws(DomainError) -> SharedItemClaimState {
        var seen = Set<Participant.ID>()
        var uniqueOrdered: [Participant.ID] = []

        for claimantID in claimantIDs {
            guard validParticipants.contains(claimantID) else {
                throw .unknownParticipant(claimantID)
            }
            if seen.insert(claimantID).inserted {
                uniqueOrdered.append(claimantID)
            }
        }

        guard let firstClaimant = uniqueOrdered.first else {
            return .unassigned
        }

        if uniqueOrdered.count == 1 {
            return .assigned(.wholeItem(firstClaimant))
        }

        return .assigned(.equal(seen))
    }
}

/// Domain representation of a line item in a shared collaborative session.
nonisolated struct SharedReceiptLineItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let unitPrice: Money
    let quantity: Int
    let claimantIDs: [Participant.ID]
    let lineTotal: Money

    init(
        id: UUID,
        name: String,
        unitPrice: Money,
        quantity: Int = 1,
        claimantIDs: [Participant.ID] = []
    ) throws(DomainError) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw .emptyItemName
        }
        guard unitPrice.amountInMinorUnits >= 0 else {
            throw .negativeAmount(unitPrice.amountInMinorUnits)
        }
        guard quantity >= 1 else {
            throw .invalidQuantity(quantity)
        }

        self.id = id
        self.name = trimmedName
        self.unitPrice = unitPrice
        self.quantity = quantity
        self.claimantIDs = claimantIDs
        self.lineTotal = try unitPrice.multiplied(by: quantity)
    }

    func claimState(validParticipants: Set<Participant.ID>) throws(DomainError) -> SharedItemClaimState {
        try SharedItemClaimState.fromClaimants(claimantIDs, validParticipants: validParticipants)
    }
}

/// Real-time collaborative split preview preserving exact penny conservation across claimed and unclaimed items.
/// Invariant: `splitResult.totalAllocated + unclaimedSubtotal == grandTotal`.
nonisolated struct CollaborationSplitPreview: Equatable, Sendable {
    let receiptID: UUID
    let currency: Currency
    let splitResult: ReceiptSplitResult
    let assignedItemsSubtotal: Money
    let unclaimedSubtotal: Money
    let unclaimedItemIDs: Set<UUID>
    let grandTotal: Money

    static func compute(
        receiptID: UUID,
        currency: Currency,
        participants: [Participant],
        items: [SharedReceiptLineItem],
        tax: Money,
        tip: Money
    ) throws(DomainError) -> CollaborationSplitPreview {
        guard !participants.isEmpty else {
            throw .noParticipantsInReceipt
        }
        guard tax.currency == currency else {
            throw .currencyMismatch(expected: currency, actual: tax.currency)
        }
        guard tip.currency == currency else {
            throw .currencyMismatch(expected: currency, actual: tip.currency)
        }
        guard tax.amountInMinorUnits >= 0 else {
            throw .negativeAmount(tax.amountInMinorUnits)
        }
        guard tip.amountInMinorUnits >= 0 else {
            throw .negativeAmount(tip.amountInMinorUnits)
        }

        let validParticipantIDs = Set(participants.map(\.id))
        var claimedDomainItems: [ReceiptItem] = []
        var unclaimedItemIDs = Set<UUID>()
        var unclaimedCents: Int64 = 0
        var assignedCents: Int64 = 0

        for item in items {
            guard item.unitPrice.currency == currency else {
                throw .currencyMismatch(expected: currency, actual: item.unitPrice.currency)
            }

            switch try item.claimState(validParticipants: validParticipantIDs) {
            case .unassigned:
                unclaimedItemIDs.insert(item.id)
                let (updated, overflow) = unclaimedCents.addingReportingOverflow(item.lineTotal.amountInMinorUnits)
                if overflow {
                    throw .negativeAmount(item.lineTotal.amountInMinorUnits)
                }
                unclaimedCents = updated

            case .assigned(let splitMode):
                let domainItem = try ReceiptItem(
                    id: item.id,
                    name: item.name,
                    unitPrice: item.unitPrice,
                    quantity: item.quantity,
                    splitMode: splitMode
                )
                claimedDomainItems.append(domainItem)
                let (updated, overflow) = assignedCents.addingReportingOverflow(domainItem.lineTotal.amountInMinorUnits)
                if overflow {
                    throw .negativeAmount(domainItem.lineTotal.amountInMinorUnits)
                }
                assignedCents = updated
            }
        }

        let claimedReceipt = try Receipt(
            id: receiptID,
            currency: currency,
            participants: participants,
            items: claimedDomainItems,
            tax: tax,
            tip: tip
        )
        let splitResult = try SplitEngine.calculateSplit(for: claimedReceipt)

        let (subtotalSum, subtotalOverflow) = assignedCents.addingReportingOverflow(unclaimedCents)
        let (withTax, taxOverflow) = subtotalSum.addingReportingOverflow(tax.amountInMinorUnits)
        let (grandTotalCents, tipOverflow) = withTax.addingReportingOverflow(tip.amountInMinorUnits)
        if subtotalOverflow || taxOverflow || tipOverflow {
            throw .negativeAmount(assignedCents)
        }

        return CollaborationSplitPreview(
            receiptID: receiptID,
            currency: currency,
            splitResult: splitResult,
            assignedItemsSubtotal: Money(amountInMinorUnits: assignedCents, currency: currency),
            unclaimedSubtotal: Money(amountInMinorUnits: unclaimedCents, currency: currency),
            unclaimedItemIDs: unclaimedItemIDs,
            grandTotal: Money(amountInMinorUnits: grandTotalCents, currency: currency)
        )
    }
}
