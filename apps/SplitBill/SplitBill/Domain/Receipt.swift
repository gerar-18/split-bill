import Foundation

/// A restaurant receipt containing participants, line items, and optional tax/tip amounts.
nonisolated struct Receipt: Identifiable, Equatable, Sendable {
    let id: UUID
    let currency: Currency
    let participants: [Participant]
    let items: [ReceiptItem]
    let tax: Money
    let tip: Money

    /// Creates a validated receipt.
    ///
    /// - Parameters:
    ///   - id: Unique receipt identifier.
    ///   - currency: The base currency of the receipt.
    ///   - participants: The list of people at the table. Deduplicated by `id` preserving first-seen order.
    ///   - items: The line items consumed.
    ///   - tax: Optional tax amount (defaults to zero in receipt currency).
    ///   - tip: Optional tip amount (defaults to zero in receipt currency).
    init(
        id: UUID = UUID(),
        currency: Currency,
        participants: [Participant],
        items: [ReceiptItem] = [],
        tax: Money? = nil,
        tip: Money? = nil
    ) throws(DomainError) {
        guard !participants.isEmpty else {
            throw .noParticipantsInReceipt
        }

        // Deduplicate participants preserving canonical first-seen order.
        var seenParticipantIDs = Set<Participant.ID>()
        var canonicalParticipants: [Participant] = []
        for participant in participants {
            if seenParticipantIDs.insert(participant.id).inserted {
                canonicalParticipants.append(participant)
            }
        }

        let resolvedTax = tax ?? Money.zero(currency: currency)
        let resolvedTip = tip ?? Money.zero(currency: currency)

        guard resolvedTax.currency == currency else {
            throw .currencyMismatch(expected: currency, actual: resolvedTax.currency)
        }
        guard resolvedTip.currency == currency else {
            throw .currencyMismatch(expected: currency, actual: resolvedTip.currency)
        }
        guard resolvedTax.amountInMinorUnits >= 0 else {
            throw .negativeAmount(resolvedTax.amountInMinorUnits)
        }
        guard resolvedTip.amountInMinorUnits >= 0 else {
            throw .negativeAmount(resolvedTip.amountInMinorUnits)
        }

        let validParticipantIDs = seenParticipantIDs
        for item in items {
            guard item.unitPrice.currency == currency else {
                throw .currencyMismatch(expected: currency, actual: item.unitPrice.currency)
            }
            try item.splitMode.validate(validParticipants: validParticipantIDs)
        }

        self.id = id
        self.currency = currency
        self.participants = canonicalParticipants
        self.items = items
        self.tax = resolvedTax
        self.tip = resolvedTip
    }

    /// The sum of all line item totals before tax and tip.
    var itemsSubtotal: Money {
        let totalCents = items.reduce(Int64(0)) { $0 + $1.lineTotal.amountInMinorUnits }
        return Money(amountInMinorUnits: totalCents, currency: currency)
    }

    /// The grand total of the receipt: `itemsSubtotal + tax + tip`.
    var total: Money {
        let totalCents = itemsSubtotal.amountInMinorUnits + tax.amountInMinorUnits + tip.amountInMinorUnits
        return Money(amountInMinorUnits: totalCents, currency: currency)
    }
}
