import Foundation
import Observation

/// An editable representation of an individual item candidate detected during receipt OCR parsing.
///
/// Enables users to review, edit name, quantity, unit price, or exclude the item prior to importing it
/// into the live receipt editor session.
@Observable
@MainActor
final class EditableParsedItemDraft: Identifiable, @unchecked Sendable {
    let id: UUID
    var isIncluded: Bool
    var name: String
    var quantity: Int
    var unitPriceText: String
    let sourceLineText: String

    /// Initializes from an immutable domain candidate.
    init(from candidate: ParsedReceiptItemCandidate) {
        self.id = candidate.id
        self.isIncluded = true
        self.name = candidate.name
        self.quantity = candidate.quantity
        self.unitPriceText = MoneyFormatter.decimalString(from: candidate.unitPrice)
        self.sourceLineText = candidate.sourceLineText
    }

    /// Manual initializer for testing or user-added items.
    init(
        id: UUID = UUID(),
        isIncluded: Bool = true,
        name: String = "",
        quantity: Int = 1,
        unitPriceText: String = "",
        sourceLineText: String = ""
    ) {
        self.id = id
        self.isIncluded = isIncluded
        self.name = name
        self.quantity = max(1, quantity)
        self.unitPriceText = unitPriceText
        self.sourceLineText = sourceLineText
    }

    /// Parses the editable `unitPriceText` into a `Money` value using pure integer arithmetic.
    func parsedUnitPrice(currency: Currency) -> Money? {
        MoneyParser.parseMajorUnits(from: unitPriceText, currency: currency)
    }

    /// Calculates the line total (`parsedUnitPrice * quantity`) without floating-point arithmetic.
    func lineTotal(currency: Currency) -> Money? {
        guard let unitPrice = parsedUnitPrice(currency: currency) else { return nil }
        guard quantity > 0 else { return nil }
        return unitPrice.multiplying(by: quantity)
    }
}

/// An interactive draft model representing a parsed receipt candidate pending user confirmation.
///
/// Follows ADR-002: acts as an observable UI draft bridge between raw OCR candidates and
/// the validated domain receipt model.
@Observable
@MainActor
final class ParsedReceiptReviewDraft: @unchecked Sendable {
    let currency: Currency
    var merchantName: String
    var items: [EditableParsedItemDraft]
    var includeDetectedTax: Bool
    var taxText: String
    var includeDetectedTip: Bool
    var tipText: String
    var detectedTotal: Money?
    var detectedSubtotal: Money?
    let unclassifiedLines: [String]

    /// Initializes a review draft from an immutable parsed candidate.
    init(from candidate: ParsedReceiptCandidate) {
        self.currency = candidate.currency
        self.merchantName = candidate.merchantName ?? ""
        self.items = candidate.items.map { EditableParsedItemDraft(from: $0) }

        if let tax = candidate.detectedTax, tax.amountInMinorUnits > 0 {
            self.includeDetectedTax = true
            self.taxText = MoneyFormatter.decimalString(from: tax)
        } else {
            self.includeDetectedTax = false
            self.taxText = ""
        }

        if let tip = candidate.detectedSuggestedTip, tip.amountInMinorUnits > 0 {
            self.includeDetectedTip = true
            self.tipText = MoneyFormatter.decimalString(from: tip)
        } else {
            self.includeDetectedTip = false
            self.tipText = ""
        }

        self.detectedTotal = candidate.detectedTotal
        self.detectedSubtotal = candidate.detectedSubtotal
        self.unclassifiedLines = candidate.unclassifiedLines
    }

    /// Manual initializer for testing or custom setup.
    init(
        currency: Currency = .mxn,
        merchantName: String = "",
        items: [EditableParsedItemDraft] = [],
        includeDetectedTax: Bool = false,
        taxText: String = "",
        includeDetectedTip: Bool = false,
        tipText: String = "",
        detectedTotal: Money? = nil,
        detectedSubtotal: Money? = nil,
        unclassifiedLines: [String] = []
    ) {
        self.currency = currency
        self.merchantName = merchantName
        self.items = items
        self.includeDetectedTax = includeDetectedTax
        self.taxText = taxText
        self.includeDetectedTip = includeDetectedTip
        self.tipText = tipText
        self.detectedTotal = detectedTotal
        self.detectedSubtotal = detectedSubtotal
        self.unclassifiedLines = unclassifiedLines
    }

    // MARK: - Computed Financial Properties

    /// The sum of all active, included line items.
    var computedItemsSubtotal: Money {
        let totalMinor = items
            .filter(\.isIncluded)
            .compactMap { $0.lineTotal(currency: currency)?.amountInMinorUnits }
            .reduce(Int64(0), +)
        return Money(amountInMinorUnits: totalMinor, currency: currency)
    }

    /// The tax amount resolved from `taxText` if `includeDetectedTax` is enabled.
    var resolvedTax: Money? {
        guard includeDetectedTax else { return nil }
        return MoneyParser.parseMajorUnits(from: taxText, currency: currency)
    }

    /// The tip amount resolved from `tipText` if `includeDetectedTip` is enabled.
    var resolvedTip: Money? {
        guard includeDetectedTip else { return nil }
        return MoneyParser.parseMajorUnits(from: tipText, currency: currency)
    }

    /// Real-time reconciliation diagnostic evaluating active item selections and toggles.
    var reconciliation: ReceiptReconciliationDiagnostic {
        let includedItems = items.filter(\.isIncluded)
        guard !includedItems.isEmpty else {
            return ReceiptReconciliationDiagnostic(
                currency: currency,
                computedItemsSubtotal: computedItemsSubtotal,
                detectedSubtotal: detectedSubtotal,
                detectedTax: resolvedTax,
                detectedTotal: detectedTotal,
                status: .empty,
                subtotalMatches: nil,
                totalMatches: nil
            )
        }

        let subtotalMatches: Bool?
        if let detectedSubtotal {
            subtotalMatches = (computedItemsSubtotal == detectedSubtotal)
        } else {
            subtotalMatches = nil
        }

        let totalMatches: Bool?
        let status: ReceiptReconciliationStatus

        if let detectedTotal {
            let taxMinor = resolvedTax?.amountInMinorUnits ?? 0
            let expectedTotalMinor = computedItemsSubtotal.amountInMinorUnits + taxMinor
            let actualTotalMinor = detectedTotal.amountInMinorUnits
            let matches = (expectedTotalMinor == actualTotalMinor)
            totalMatches = matches

            if matches {
                status = .verified
            } else {
                let diff = actualTotalMinor - expectedTotalMinor
                status = .discrepancy(differenceInMinorUnits: diff, currency: currency)
            }
        } else if let detectedSubtotal {
            totalMatches = nil
            if computedItemsSubtotal == detectedSubtotal {
                status = .verified
            } else {
                let diff = detectedSubtotal.amountInMinorUnits - computedItemsSubtotal.amountInMinorUnits
                status = .discrepancy(differenceInMinorUnits: diff, currency: currency)
            }
        } else {
            totalMatches = nil
            status = .partial
        }

        return ReceiptReconciliationDiagnostic(
            currency: currency,
            computedItemsSubtotal: computedItemsSubtotal,
            detectedSubtotal: detectedSubtotal,
            detectedTax: resolvedTax,
            detectedTotal: detectedTotal,
            status: status,
            subtotalMatches: subtotalMatches,
            totalMatches: totalMatches
        )
    }

    // MARK: - Mutation Methods

    /// Adds a new editable item draft to the list.
    func addItem() {
        let newItem = EditableParsedItemDraft(
            id: UUID(),
            isIncluded: true,
            name: "",
            quantity: 1,
            unitPriceText: "",
            sourceLineText: "Manual"
        )
        items.append(newItem)
    }

    /// Removes an item draft by its unique identifier.
    func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
    }
}
