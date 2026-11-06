import Foundation

/// Pure domain-level money parser converting textual representations into exact integer minor units.
///
/// Complies with ADR-002 by avoiding binary floating-point types completely.
nonisolated enum MoneyParser: Sendable {

    /// Parses a string formatted in major units (e.g. "$85.00", "85.5", "1,067.20", "45")
    /// into a `Money` value with exact integer minor units.
    static func parseMajorUnits(from text: String, currency: Currency = .mxn) -> Money? {
        guard let minorUnits = parseMinorUnits(from: text, currency: currency) else {
            return nil
        }
        return Money(amountInMinorUnits: minorUnits, currency: currency)
    }

    /// Parses a price string into integer minor units without binary floating-point arithmetic.
    static func parseMinorUnits(from text: String, currency: Currency = .mxn) -> Int64? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Negative values are rejected in receipt item parsing
        guard !trimmed.contains("-") else { return nil }

        // Strip currency symbols and common codes
        var cleaned = trimmed
        cleaned = cleaned.replacingOccurrences(of: currency.code, with: "", options: .caseInsensitive, range: nil)
        cleaned = cleaned.replacingOccurrences(of: Currency.mxn.code, with: "", options: .caseInsensitive, range: nil)
        cleaned = cleaned.replacingOccurrences(of: Currency.usd.code, with: "", options: .caseInsensitive, range: nil)
        cleaned = cleaned.replacingOccurrences(of: "$", with: "")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        // Normalize separators:
        // If it contains '.', treat commas as thousands separators (e.g. "1,067.20")
        // If no '.' but has comma with <= scale digits at end, treat comma as decimal
        let normalized: String
        if cleaned.contains(".") {
            normalized = cleaned.replacingOccurrences(of: ",", with: "")
        } else if cleaned.contains(",") {
            let commaParts = cleaned.split(separator: ",", omittingEmptySubsequences: false)
            if commaParts.count == 2 && commaParts[1].count <= currency.minorUnitScale {
                normalized = "\(commaParts[0]).\(commaParts[1])"
            } else {
                normalized = cleaned.replacingOccurrences(of: ",", with: "")
            }
        } else {
            normalized = cleaned
        }

        let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return nil }

        let integerPartString = String(parts[0])
        let fractionPartString = parts.count == 2 ? String(parts[1]) : ""

        guard fractionPartString.count <= currency.minorUnitScale else { return nil }

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
        let (scaledInteger, overflow) = integerUnits.multipliedReportingOverflow(by: scaleMultiplier)
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

    private static func tenToThePower(of exponent: Int) -> Int64 {
        var result: Int64 = 1
        for _ in 0..<exponent {
            result *= 10
        }
        return result
    }
}
