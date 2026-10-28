import Foundation

/// Tip selection state supporting percentage presets and custom monetary amount entry.
nonisolated enum TipSelection: Equatable, Hashable, Sendable {
    case percentage(Int)
    case custom

    /// Common restaurant percentage tip presets.
    static let presets: [Int] = [0, 10, 15, 20]

    /// Resolves the tip amount in minor units based on subtotal and custom input text.
    ///
    /// - Percentage tips use exact half-up integer arithmetic:
    ///   `cents = (subtotal.amountInMinorUnits * Int64(pct) + 50) / 100`
    /// - Custom tips are parsed via `MoneyFormatter.parseMinorUnits(from:customText, currency:)`.
    ///
    /// - Parameters:
    ///   - subtotal: The items subtotal to calculate percentage against.
    ///   - customText: The text string entered by the user when `.custom` is active.
    /// - Returns: A non-negative `Money` tip amount in the subtotal currency.
    func resolveMoney(subtotal: Money, customText: String) -> Money {
        switch self {
        case .percentage(let percentage):
            guard percentage > 0 else {
                return Money.zero(currency: subtotal.currency)
            }
            guard subtotal.amountInMinorUnits > 0 else {
                return Money.zero(currency: subtotal.currency)
            }
            let subtotalUnits = subtotal.amountInMinorUnits
            let product = subtotalUnits * Int64(percentage)
            let roundedUnits = (product + 50) / 100
            return Money(amountInMinorUnits: roundedUnits, currency: subtotal.currency)

        case .custom:
            let parsedUnits = MoneyFormatter.parseMinorUnits(from: customText, currency: subtotal.currency) ?? 0
            let nonNegativeUnits = max(0, parsedUnits)
            return Money(amountInMinorUnits: nonNegativeUnits, currency: subtotal.currency)
        }
    }
}
