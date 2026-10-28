import Foundation

/// A line item on a receipt with unit price, quantity, and split assignment.
nonisolated struct ReceiptItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let unitPrice: Money
    let quantity: Int
    let splitMode: SplitMode
    let lineTotal: Money

    /// Creates a validated receipt item and precomputes its exact line total (`unitPrice * quantity`).
    init(
        id: UUID = UUID(),
        name: String,
        unitPrice: Money,
        quantity: Int = 1,
        splitMode: SplitMode
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
        self.splitMode = splitMode
        self.lineTotal = try unitPrice.multiplied(by: quantity)
    }
}
