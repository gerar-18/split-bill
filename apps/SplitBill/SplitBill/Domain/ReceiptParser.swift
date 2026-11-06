import Foundation

// MARK: - Extension on Money for Candidate Calculations

extension Money {
    /// Non-throwing convenience multiplying the monetary amount by a non-negative integer quantity.
    nonisolated func multiplying(by quantity: Int) -> Money {
        let safeQuantity = max(0, quantity)
        return Money(
            amountInMinorUnits: amountInMinorUnits * Int64(safeQuantity),
            currency: currency
        )
    }
}

// MARK: - Parsed Item Candidate

/// A parsed candidate for an individual line item detected on a receipt.
nonisolated struct ParsedReceiptItemCandidate: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let name: String
    let quantity: Int
    let unitPrice: Money
    let sourceLineText: String

    var lineTotal: Money {
        unitPrice.multiplying(by: quantity)
    }

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Int = 1,
        unitPrice: Money,
        sourceLineText: String = ""
    ) {
        self.id = id
        self.name = name
        self.quantity = max(1, quantity)
        self.unitPrice = unitPrice
        self.sourceLineText = sourceLineText
    }
}

// MARK: - Reconciliation Diagnostic Status

/// High-level mathematical verification status for a parsed receipt.
nonisolated enum ReceiptReconciliationStatus: Equatable, Hashable, Sendable {
    /// Mathematical invariant holds: computed items subtotal (+ detected tax) equals detected total.
    case verified

    /// Items were detected, but neither grand total nor subtotal was identified on the ticket.
    case partial

    /// The detected total differs from the computed items subtotal (+ detected tax).
    case discrepancy(differenceInMinorUnits: Int64, currency: Currency)

    /// No receipt items were detected in the source text.
    case empty
}

// MARK: - Reconciliation Diagnostic

/// Detailed mathematical breakdown comparing detected summary lines against computed line items.
nonisolated struct ReceiptReconciliationDiagnostic: Equatable, Sendable {
    let currency: Currency
    let computedItemsSubtotal: Money
    let detectedSubtotal: Money?
    let detectedTax: Money?
    let detectedTotal: Money?
    let status: ReceiptReconciliationStatus
    let subtotalMatches: Bool?
    let totalMatches: Bool?

    init(
        currency: Currency,
        computedItemsSubtotal: Money,
        detectedSubtotal: Money?,
        detectedTax: Money?,
        detectedTotal: Money?,
        status: ReceiptReconciliationStatus,
        subtotalMatches: Bool?,
        totalMatches: Bool?
    ) {
        self.currency = currency
        self.computedItemsSubtotal = computedItemsSubtotal
        self.detectedSubtotal = detectedSubtotal
        self.detectedTax = detectedTax
        self.detectedTotal = detectedTotal
        self.status = status
        self.subtotalMatches = subtotalMatches
        self.totalMatches = totalMatches
    }
}

// MARK: - Parsed Receipt Candidate

/// Complete structured representation of a receipt parsed from raw text or OCR lines.
nonisolated struct ParsedReceiptCandidate: Equatable, Sendable {
    let currency: Currency
    let merchantName: String?
    let items: [ParsedReceiptItemCandidate]
    let detectedSubtotal: Money?
    let detectedTax: Money?
    let detectedSuggestedTip: Money?
    let detectedTipPercentage: Int?
    let detectedTotal: Money?
    let unclassifiedLines: [String]
    let reconciliation: ReceiptReconciliationDiagnostic

    init(
        currency: Currency,
        merchantName: String?,
        items: [ParsedReceiptItemCandidate],
        detectedSubtotal: Money?,
        detectedTax: Money?,
        detectedSuggestedTip: Money?,
        detectedTipPercentage: Int?,
        detectedTotal: Money?,
        unclassifiedLines: [String],
        reconciliation: ReceiptReconciliationDiagnostic
    ) {
        self.currency = currency
        self.merchantName = merchantName
        self.items = items
        self.detectedSubtotal = detectedSubtotal
        self.detectedTax = detectedTax
        self.detectedSuggestedTip = detectedSuggestedTip
        self.detectedTipPercentage = detectedTipPercentage
        self.detectedTotal = detectedTotal
        self.unclassifiedLines = unclassifiedLines
        self.reconciliation = reconciliation
    }
}

// MARK: - Receipt Parser Protocol

/// Contract for turning raw receipt lines into a structured `ParsedReceiptCandidate`.
protocol ReceiptParser: Sendable {
    func parse(lines: [String], currency: Currency) -> ParsedReceiptCandidate
}

extension ReceiptParser {
    func parse(rawText: String, currency: Currency) -> ParsedReceiptCandidate {
        let lines = rawText.components(separatedBy: .newlines)
        return parse(lines: lines, currency: currency)
    }
}
