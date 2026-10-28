import Foundation

/// ISO 4217 currency representation with explicit minor-unit scale.
nonisolated struct Currency: Equatable, Hashable, Sendable {
    let code: String
    let minorUnitScale: Int

    static let mxn = Currency(code: "MXN", minorUnitScale: 2)
    static let usd = Currency(code: "USD", minorUnitScale: 2)
}

/// Exact monetary value stored in integer minor units (e.g., centavos/cents).
nonisolated struct Money: Equatable, Hashable, Sendable {
    let amountInMinorUnits: Int64
    let currency: Currency

    /// Creates a monetary value directly from integer minor units.
    init(amountInMinorUnits: Int64, currency: Currency) {
        self.amountInMinorUnits = amountInMinorUnits
        self.currency = currency
    }

    /// Convenience factory for a zero amount in the specified currency.
    static func zero(currency: Currency) -> Money {
        Money(amountInMinorUnits: 0, currency: currency)
    }

    /// Validated factory that rejects negative minor-unit amounts.
    static func nonNegative(minorUnits: Int64, currency: Currency) throws(DomainError) -> Money {
        guard minorUnits >= 0 else {
            throw .negativeAmount(minorUnits)
        }
        return Money(amountInMinorUnits: minorUnits, currency: currency)
    }

    /// Returns the sum of two monetary amounts of the same currency.
    func adding(_ other: Money) throws(DomainError) -> Money {
        try validateSameCurrency(as: other)
        return Money(
            amountInMinorUnits: amountInMinorUnits + other.amountInMinorUnits,
            currency: currency
        )
    }

    /// Returns the non-negative difference between two monetary amounts of the same currency.
    func subtracting(_ other: Money) throws(DomainError) -> Money {
        try validateSameCurrency(as: other)
        let result = amountInMinorUnits - other.amountInMinorUnits
        guard result >= 0 else {
            throw .negativeAmount(result)
        }
        return Money(amountInMinorUnits: result, currency: currency)
    }

    /// Multiplies the monetary amount by a non-negative integer quantity.
    func multiplied(by quantity: Int) throws(DomainError) -> Money {
        guard quantity >= 0 else {
            throw .invalidQuantity(quantity)
        }
        return Money(
            amountInMinorUnits: amountInMinorUnits * Int64(quantity),
            currency: currency
        )
    }

    /// Compares whether this amount is strictly less than another amount of the same currency.
    func isLessThan(_ other: Money) throws(DomainError) -> Bool {
        try validateSameCurrency(as: other)
        return amountInMinorUnits < other.amountInMinorUnits
    }

    private func validateSameCurrency(as other: Money) throws(DomainError) {
        guard currency == other.currency else {
            throw .currencyMismatch(expected: currency, actual: other.currency)
        }
    }
}
