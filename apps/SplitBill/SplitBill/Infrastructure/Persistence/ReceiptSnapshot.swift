import Foundation

/// Pure, immutable value representation of a receipt draft or persisted state.
///
/// `ReceiptSnapshot` serves as the intermediary transfer object between the UI,
/// the SwiftData persistence layer (`StoredReceipt`), and the pure domain model (`Receipt`).
nonisolated struct ReceiptSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var currency: Currency
    var participants: [Participant]
    var items: [ReceiptItem]
    var tax: Money
    var tipSelection: TipSelection
    var customTipMinorUnits: Int64?
    var receiptImageData: Data?
    var ocrRawText: String?

    init(
        id: UUID = UUID(),
        title: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        currency: Currency = .mxn,
        participants: [Participant] = [],
        items: [ReceiptItem] = [],
        tax: Money? = nil,
        tipSelection: TipSelection = .percentage(10),
        customTipMinorUnits: Int64? = nil,
        receiptImageData: Data? = nil,
        ocrRawText: String? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.currency = currency
        self.participants = participants
        self.items = items
        self.tax = tax ?? Money.zero(currency: currency)
        self.tipSelection = tipSelection
        self.customTipMinorUnits = customTipMinorUnits
        self.receiptImageData = receiptImageData
        self.ocrRawText = ocrRawText
    }

    /// Sum of all line item totals before tax and tip.
    var itemsSubtotal: Money {
        let totalCents = items.reduce(Int64(0)) { $0 + $1.lineTotal.amountInMinorUnits }
        return Money(amountInMinorUnits: totalCents, currency: currency)
    }

    /// Resolves the tip amount in minor units based on `tipSelection` and `itemsSubtotal`.
    var resolvedTip: Money {
        switch tipSelection {
        case .percentage(let percentage):
            guard percentage > 0, itemsSubtotal.amountInMinorUnits > 0 else {
                return Money.zero(currency: currency)
            }
            let subtotalUnits = itemsSubtotal.amountInMinorUnits
            let product = subtotalUnits * Int64(percentage)
            let roundedUnits = (product + 50) / 100
            return Money(amountInMinorUnits: roundedUnits, currency: currency)

        case .custom:
            let amount = max(0, customTipMinorUnits ?? 0)
            return Money(amountInMinorUnits: amount, currency: currency)
        }
    }

    /// The grand total of the receipt: `itemsSubtotal + tax + resolvedTip`.
    var grandTotal: Money {
        let totalCents = itemsSubtotal.amountInMinorUnits + tax.amountInMinorUnits + resolvedTip.amountInMinorUnits
        return Money(amountInMinorUnits: totalCents, currency: currency)
    }

    /// Validates and converts this snapshot into a verified domain `Receipt`.
    ///
    /// - Throws: `DomainError` if validation fails (e.g. empty participants, currency mismatch, invalid split mode).
    func toDomainReceipt() throws(DomainError) -> Receipt {
        try Receipt(
            id: id,
            currency: currency,
            participants: participants,
            items: items,
            tax: tax,
            tip: resolvedTip
        )
    }
}
