import Foundation

/// Pure, deterministic money parser and formatter using integer minor units.
///
/// Complies with ADR-002 and ensures no binary floating-point types (`Float`/`Double`)
/// are ever used for monetary calculations or text conversions.
nonisolated enum MoneyFormatter {

    /// Parses a user-entered price string into exact integer minor units (e.g., cents/centavos).
    ///
    /// Supported formats:
    /// - Plain integer: `"120"` -> `12000` (for scale 2)
    /// - Standard decimal: `"125.50"` -> `12550`, `"45.5"` -> `4550`
    /// - With currency prefix/suffix: `"$125.50"`, `"  $ 125.50 MXN  "` -> `12550`
    /// - With thousands separator: `"1,234.50"` -> `123450`, `"1,234"` -> `123400`
    /// - Decimal comma (single comma with <= scale digits): `"125,50"` -> `12550`
    ///
    /// Rejections (returns `nil`):
    /// - Negative values: `"-10"`, `"-0.50"`
    /// - Empty or whitespace-only strings
    /// - Non-numeric characters: `"abc"`, `"$"`
    /// - Exceeding minor unit scale decimal places: `"12.345"` (for scale 2)
    /// - Multiple decimal separators: `"12.34.56"`
    ///
    /// - Parameters:
    ///   - text: The user input string.
    ///   - currency: The target currency defining `minorUnitScale`.
    /// - Returns: The amount in integer minor units, or `nil` if the input is invalid.
    static func parseMinorUnits(from text: String, currency: Currency = .mxn) -> Int64? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Rejection rule: negative amounts are not permitted.
        guard !trimmed.contains("-") else { return nil }

        // Strip currency symbols and common currency codes case-insensitively.
        var cleaned = trimmed
        cleaned = cleaned.replacingOccurrences(of: currency.code, with: "", options: .caseInsensitive, range: nil)
        cleaned = cleaned.replacingOccurrences(of: Currency.mxn.code, with: "", options: .caseInsensitive, range: nil)
        cleaned = cleaned.replacingOccurrences(of: Currency.usd.code, with: "", options: .caseInsensitive, range: nil)
        cleaned = cleaned.replacingOccurrences(of: "$", with: "")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        // Normalize separators:
        // If the string contains '.', treat any commas as thousands separators (e.g., "1,234.50").
        // If the string contains no '.', but has a single ',' followed by 1 or 2 digits, treat ',' as decimal point.
        let normalized: String
        if cleaned.contains(".") {
            normalized = cleaned.replacingOccurrences(of: ",", with: "")
        } else if cleaned.contains(",") {
            let commaComponents = cleaned.split(separator: ",", omittingEmptySubsequences: false)
            if commaComponents.count == 2 && commaComponents[1].count <= currency.minorUnitScale {
                // Comma used as decimal point (e.g., "125,50" -> "125.50")
                normalized = "\(commaComponents[0]).\(commaComponents[1])"
            } else {
                // Comma used as thousands grouping (e.g., "1,234" -> "1234")
                normalized = cleaned.replacingOccurrences(of: ",", with: "")
            }
        } else {
            normalized = cleaned
        }

        let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return nil }

        let integerPartString = String(parts[0])
        let fractionPartString = parts.count == 2 ? String(parts[1]) : ""

        // Validate fraction part length does not exceed currency minor unit scale
        guard fractionPartString.count <= currency.minorUnitScale else { return nil }

        // Validate characters are strictly ASCII digits
        if !integerPartString.isEmpty {
            guard integerPartString.allSatisfy({ $0.isASCII && $0.isWholeNumber }) else {
                return nil
            }
        }
        if !fractionPartString.isEmpty {
            guard fractionPartString.allSatisfy({ $0.isASCII && $0.isWholeNumber }) else {
                return nil
            }
        }

        // Must have at least integer or fraction part
        guard !integerPartString.isEmpty || !fractionPartString.isEmpty else {
            return nil
        }

        let integerUnits: Int64
        if integerPartString.isEmpty {
            integerUnits = 0
        } else {
            guard let parsedInt = Int64(integerPartString), parsedInt >= 0 else {
                return nil
            }
            integerUnits = parsedInt
        }

        let scaleMultiplier = tenToThePower(of: currency.minorUnitScale)
        let scaledInteger: Int64
        let overflow: Bool
        (scaledInteger, overflow) = integerUnits.multipliedReportingOverflow(by: scaleMultiplier)
        guard !overflow else { return nil }

        let paddedFraction = fractionPartString.padding(
            toLength: currency.minorUnitScale,
            withPad: "0",
            startingAt: 0
        )
        let fractionUnits: Int64
        if paddedFraction.isEmpty {
            fractionUnits = 0
        } else {
            guard let parsedFrac = Int64(paddedFraction), parsedFrac >= 0 else {
                return nil
            }
            fractionUnits = parsedFrac
        }

        let (total, addOverflow) = scaledInteger.addingReportingOverflow(fractionUnits)
        guard !addOverflow else { return nil }

        return total
    }

    /// Formats a `Money` value into an editable decimal string without symbol or currency code (e.g., `"125.50"`).
    static func decimalString(from money: Money) -> String {
        let absAmount = UInt64(money.amountInMinorUnits.magnitude)
        let scale = money.currency.minorUnitScale
        let scaleMultiplier = UInt64(tenToThePower(of: scale))

        let majorUnits = absAmount / scaleMultiplier
        let minorUnits = absAmount % scaleMultiplier

        let formattedMinor = String(format: "%0*llu", scale, minorUnits)
        let isNegative = money.amountInMinorUnits < 0
        let prefix = isNegative ? "-" : ""
        return "\(prefix)\(majorUnits).\(formattedMinor)"
    }

    /// Formats a `Money` value into a user-facing string (e.g., `"$125.50 MXN"`).
    ///
    /// - Parameters:
    ///   - money: The monetary value to format.
    ///   - includeCurrencyCode: Whether to append the ISO currency code (default: `true`).
    /// - Returns: A deterministically formatted currency string.
    static func string(from money: Money, includeCurrencyCode: Bool = true) -> String {
        let isNegative = money.amountInMinorUnits < 0
        let absAmount = UInt64(money.amountInMinorUnits.magnitude)
        let scale = money.currency.minorUnitScale
        let scaleMultiplier = UInt64(tenToThePower(of: scale))

        let majorUnits = Int64(clamping: absAmount / scaleMultiplier)
        let minorUnits = absAmount % scaleMultiplier

        let formattedMajor = formatThousandsGrouping(majorUnits)
        let formattedMinor = String(format: "%0*llu", scale, minorUnits)

        let prefix = isNegative ? "-$" : "$"
        let base = "\(prefix)\(formattedMajor).\(formattedMinor)"

        if includeCurrencyCode {
            return "\(base) \(money.currency.code)"
        } else {
            return base
        }
    }

    // MARK: - Private Helpers

    private static func tenToThePower(of exponent: Int) -> Int64 {
        var result: Int64 = 1
        for _ in 0..<exponent {
            result *= 10
        }
        return result
    }

    private static func formatThousandsGrouping(_ value: Int64) -> String {
        let stringValue = String(value)
        guard stringValue.count > 3 else { return stringValue }

        var result = ""
        var count = 0
        for char in stringValue.reversed() {
            if count > 0 && count % 3 == 0 {
                result.append(",")
            }
            result.append(char)
            count += 1
        }
        return String(result.reversed())
    }
}
