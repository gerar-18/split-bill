import Testing
@testable import SplitBill

@Suite("Money & Currency Domain Tests")
struct MoneyTests {

    @Test("Creates zero and positive Money in MXN and USD")
    func createsZeroAndPositiveMoney() throws {
        let zeroMXN = Money.zero(currency: .mxn)
        #expect(zeroMXN.amountInMinorUnits == 0)
        #expect(zeroMXN.currency == .mxn)
        #expect(Currency.mxn.code == "MXN")
        #expect(Currency.mxn.minorUnitScale == 2)

        let zeroUSD = try Money.nonNegative(minorUnits: 0, currency: .usd)
        #expect(zeroUSD == Money.zero(currency: .usd))
        #expect(Currency.usd.code == "USD")
        #expect(Currency.usd.minorUnitScale == 2)

        let positiveMXN = try Money.nonNegative(minorUnits: 12_550, currency: .mxn)
        #expect(positiveMXN.amountInMinorUnits == 12_550)
        #expect(positiveMXN.currency == .mxn)
    }

    @Test("Rejects negative minor units in Money.nonNegative")
    func rejectsNegativeMinorUnits() {
        #expect(throws: DomainError.negativeAmount(-1)) {
            try Money.nonNegative(minorUnits: -1, currency: .mxn)
        }
    }

    @Test("Adds and subtracts same-currency amounts", arguments: [
        (lhs: Int64(0), rhs: Int64(0), sum: Int64(0), diff: Int64(0)),
        (lhs: Int64(1_000), rhs: Int64(250), sum: Int64(1_250), diff: Int64(750)),
        (lhs: Int64(500), rhs: Int64(500), sum: Int64(1_000), diff: Int64(0)),
        (lhs: Int64(199_999), rhs: Int64(1), sum: Int64(200_000), diff: Int64(199_998))
    ])
    func addsAndSubtractsSameCurrency(lhs: Int64, rhs: Int64, sum: Int64, diff: Int64) throws {
        let first = try Money.nonNegative(minorUnits: lhs, currency: .mxn)
        let second = try Money.nonNegative(minorUnits: rhs, currency: .mxn)

        let added = try first.adding(second)
        #expect(added == Money(amountInMinorUnits: sum, currency: .mxn))

        let subtracted = try first.subtracting(second)
        #expect(subtracted == Money(amountInMinorUnits: diff, currency: .mxn))
    }

    @Test("Rejects currency mismatch in operations")
    func rejectsCurrencyMismatch() {
        let mxnAmount = Money(amountInMinorUnits: 1_000, currency: .mxn)
        let usdAmount = Money(amountInMinorUnits: 1_000, currency: .usd)

        #expect(throws: DomainError.currencyMismatch(expected: .mxn, actual: .usd)) {
            try mxnAmount.adding(usdAmount)
        }

        #expect(throws: DomainError.currencyMismatch(expected: .mxn, actual: .usd)) {
            try mxnAmount.subtracting(usdAmount)
        }

        #expect(throws: DomainError.currencyMismatch(expected: .mxn, actual: .usd)) {
            try mxnAmount.isLessThan(usdAmount)
        }
    }

    @Test("Rejects subtraction that results in a negative amount")
    func rejectsNegativeSubtractionResult() {
        let smaller = Money(amountInMinorUnits: 300, currency: .mxn)
        let larger = Money(amountInMinorUnits: 500, currency: .mxn)

        #expect(throws: DomainError.negativeAmount(-200)) {
            try smaller.subtracting(larger)
        }
    }

    @Test("Multiplies Money by non-negative quantities including large Int64 totals", arguments: [
        (unitCents: Int64(1_500), quantity: 0, expectedCents: Int64(0)),
        (unitCents: Int64(1_500), quantity: 1, expectedCents: Int64(1_500)),
        (unitCents: Int64(1_500), quantity: 3, expectedCents: Int64(4_500)),
        (unitCents: Int64(1_000_000_000), quantity: 5, expectedCents: Int64(5_000_000_000))
    ])
    func multipliesByQuantity(unitCents: Int64, quantity: Int, expectedCents: Int64) throws {
        let unitPrice = Money(amountInMinorUnits: unitCents, currency: .usd)
        let lineTotal = try unitPrice.multiplied(by: quantity)
        #expect(lineTotal == Money(amountInMinorUnits: expectedCents, currency: .usd))
    }

    @Test("Rejects negative quantity when multiplying Money")
    func rejectsNegativeQuantity() {
        let unitPrice = Money(amountInMinorUnits: 1_000, currency: .mxn)
        #expect(throws: DomainError.invalidQuantity(-2)) {
            try unitPrice.multiplied(by: -2)
        }
    }

    @Test("Compares same-currency amounts safely with isLessThan")
    func comparesSameCurrencyAmounts() throws {
        let low = Money(amountInMinorUnits: 100, currency: .mxn)
        let high = Money(amountInMinorUnits: 200, currency: .mxn)

        #expect(try low.isLessThan(high) == true)
        #expect(try high.isLessThan(low) == false)
        #expect(try low.isLessThan(low) == false)
    }
}
