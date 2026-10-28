import Foundation
import Testing
@testable import SplitBill

@Suite("MoneyFormatter Parsing & Formatting Tests")
struct MoneyFormatterTests {

    // MARK: - Parsing Tests

    @Test("Parses whole integer amounts", arguments: [
        ("0", Int64(0)),
        ("120", Int64(12_000)),
        ("125", Int64(12_500)),
        ("9999", Int64(999_900))
    ])
    func parsesWholeIntegerAmounts(input: String, expected: Int64) {
        let result = MoneyFormatter.parseMinorUnits(from: input, currency: .mxn)
        #expect(result == expected)
    }

    @Test("Parses single decimal place inputs", arguments: [
        ("125.5", Int64(12_550)),
        ("$45.5", Int64(4_550)),
        ("0.5", Int64(50)),
        (".5", Int64(50))
    ])
    func parsesSingleDecimalPlace(input: String, expected: Int64) {
        let result = MoneyFormatter.parseMinorUnits(from: input, currency: .mxn)
        #expect(result == expected)
    }

    @Test("Parses two decimal place inputs", arguments: [
        ("125.50", Int64(12_550)),
        ("0.05", Int64(5)),
        (".05", Int64(5)),
        ("0.00", Int64(0)),
        ("99.99", Int64(9_999)),
        (".99", Int64(99))
    ])
    func parsesTwoDecimalPlaces(input: String, expected: Int64) {
        let result = MoneyFormatter.parseMinorUnits(from: input, currency: .mxn)
        #expect(result == expected)
    }

    @Test("Parses inputs with thousands commas and currency symbols", arguments: [
        ("1,234.50", Int64(123_450)),
        ("1,234", Int64(123_400)),
        ("$1,234.50", Int64(123_450)),
        ("  $ 125.50 MXN  ", Int64(12_550)),
        ("125.50 USD", Int64(12_550)),
        ("1,000,000.00", Int64(100_000_000))
    ])
    func parsesFormattedStrings(input: String, expected: Int64) {
        let result = MoneyFormatter.parseMinorUnits(from: input, currency: .mxn)
        #expect(result == expected)
    }

    @Test("Parses decimal comma inputs when single comma followed by 1 or 2 digits", arguments: [
        ("125,50", Int64(12_550)),
        ("45,5", Int64(4_550)),
        ("0,05", Int64(5))
    ])
    func parsesDecimalComma(input: String, expected: Int64) {
        let result = MoneyFormatter.parseMinorUnits(from: input, currency: .mxn)
        #expect(result == expected)
    }

    @Test("Rejects invalid and malformed price strings", arguments: [
        "",
        "   ",
        "$",
        "$ ",
        "-10",
        "-10.50",
        "$-5",
        "abc",
        "12a50",
        "12.34.56",
        "12.345", // Exceeds scale 2
        "0.001",  // Exceeds scale 2
        "99.999"  // Exceeds scale 2
    ])
    func rejectsInvalidInputs(input: String) {
        let result = MoneyFormatter.parseMinorUnits(from: input, currency: .mxn)
        #expect(result == nil)
    }

    // MARK: - Formatting Tests

    @Test("Formats Money into deterministic strings")
    func formatsMoneyStrings() {
        let zero = Money(amountInMinorUnits: 0, currency: .mxn)
        #expect(MoneyFormatter.string(from: zero, includeCurrencyCode: true) == "$0.00 MXN")
        #expect(MoneyFormatter.string(from: zero, includeCurrencyCode: false) == "$0.00")

        let fiveCents = Money(amountInMinorUnits: 5, currency: .mxn)
        #expect(MoneyFormatter.string(from: fiveCents, includeCurrencyCode: true) == "$0.05 MXN")
        #expect(MoneyFormatter.string(from: fiveCents, includeCurrencyCode: false) == "$0.05")

        let standard = Money(amountInMinorUnits: 12_550, currency: .mxn)
        #expect(MoneyFormatter.string(from: standard, includeCurrencyCode: true) == "$125.50 MXN")
        #expect(MoneyFormatter.string(from: standard, includeCurrencyCode: false) == "$125.50")

        let thousands = Money(amountInMinorUnits: 123_450, currency: .usd)
        #expect(MoneyFormatter.string(from: thousands, includeCurrencyCode: true) == "$1,234.50 USD")
        #expect(MoneyFormatter.string(from: thousands, includeCurrencyCode: false) == "$1,234.50")

        let million = Money(amountInMinorUnits: 100_000_000, currency: .mxn)
        #expect(MoneyFormatter.string(from: million, includeCurrencyCode: true) == "$1,000,000.00 MXN")

        // Decimal string for TextFields
        #expect(MoneyFormatter.decimalString(from: standard) == "125.50")
        #expect(MoneyFormatter.decimalString(from: fiveCents) == "0.05")
        #expect(MoneyFormatter.decimalString(from: zero) == "0.00")
    }
}
