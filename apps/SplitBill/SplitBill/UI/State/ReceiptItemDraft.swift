import Foundation

/// Mutable draft representation of a receipt line item used in creation and editing views.
nonisolated struct ReceiptItemDraft: Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var unitPriceText: String
    var quantity: Int
    var splitModeKind: SplitModeKind
    var selectedParticipantID: Participant.ID?
    var equalParticipantIDs: Set<Participant.ID>
    var percentages: [Participant.ID: Int]
    var portions: [Participant.ID: Int]

    /// Creates a draft with configurable defaults.
    init(
        id: UUID = UUID(),
        name: String = "",
        unitPriceText: String = "",
        quantity: Int = 1,
        splitModeKind: SplitModeKind = .equal,
        selectedParticipantID: Participant.ID? = nil,
        equalParticipantIDs: Set<Participant.ID> = [],
        percentages: [Participant.ID: Int] = [:],
        portions: [Participant.ID: Int] = [:]
    ) {
        self.id = id
        self.name = name
        self.unitPriceText = unitPriceText
        self.quantity = quantity
        self.splitModeKind = splitModeKind
        self.selectedParticipantID = selectedParticipantID
        self.equalParticipantIDs = equalParticipantIDs
        self.percentages = percentages
        self.portions = portions
    }

    /// Convenience initializer to populate the draft from an existing `ReceiptItem` for editing.
    init(from item: ReceiptItem) {
        self.id = item.id
        self.name = item.name
        self.unitPriceText = MoneyFormatter.decimalString(from: item.unitPrice)
        self.quantity = item.quantity
        self.percentages = [:]
        self.portions = [:]
        self.equalParticipantIDs = []
        self.selectedParticipantID = nil

        switch item.splitMode {
        case .wholeItem(let participantID):
            self.splitModeKind = .wholeItem
            self.selectedParticipantID = participantID

        case .equal(let participantIDs):
            self.splitModeKind = .equal
            self.equalParticipantIDs = participantIDs

        case .percentage(let percentagesByParticipant):
            self.splitModeKind = .percentage
            self.percentages = percentagesByParticipant

        case .portion(let portionsByParticipant):
            self.splitModeKind = .portion
            self.portions = portionsByParticipant
        }
    }

    /// Validates draft fields and constructs an immutable domain `ReceiptItem`.
    ///
    /// - Parameter currency: The receipt currency used to parse `unitPriceText`.
    /// - Throws: `DomainError` if validation fails.
    /// - Returns: A valid `ReceiptItem`.
    func buildItem(currency: Currency) throws(DomainError) -> ReceiptItem {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw .emptyItemName
        }

        guard let minorUnits = MoneyFormatter.parseMinorUnits(from: unitPriceText, currency: currency),
              minorUnits >= 0 else {
            throw .negativeAmount(-1)
        }

        guard quantity >= 1 else {
            throw .invalidQuantity(quantity)
        }

        let splitMode: SplitMode
        switch splitModeKind {
        case .wholeItem:
            guard let participantID = selectedParticipantID else {
                throw .noParticipantsAssigned
            }
            splitMode = .wholeItem(participantID)

        case .equal:
            guard !equalParticipantIDs.isEmpty else {
                throw .noParticipantsAssigned
            }
            splitMode = .equal(equalParticipantIDs)

        case .percentage:
            guard !percentages.values.contains(where: { $0 < 0 }) else {
                throw .invalidShareValue(-1)
            }
            let activePercentages = percentages.filter { $0.value > 0 }
            guard !activePercentages.isEmpty else {
                throw .noParticipantsAssigned
            }
            let total = activePercentages.values.reduce(0, +)
            guard total == 100 else {
                throw .invalidPercentageTotal(total)
            }
            splitMode = .percentage(activePercentages)

        case .portion:
            guard !portions.values.contains(where: { $0 < 0 }) else {
                throw .invalidShareValue(-1)
            }
            let activePortions = portions.filter { $0.value > 0 }
            guard !activePortions.isEmpty else {
                throw .noParticipantsAssigned
            }
            splitMode = .portion(activePortions)
        }

        let unitPrice = Money(amountInMinorUnits: minorUnits, currency: currency)
        return try ReceiptItem(
            id: id,
            name: trimmedName,
            unitPrice: unitPrice,
            quantity: quantity,
            splitMode: splitMode
        )
    }
}
