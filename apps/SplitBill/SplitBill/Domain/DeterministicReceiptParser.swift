import Foundation

/// Pure deterministic receipt text parser.
///
/// Implements domain-driven receipt parsing rules with zero dependency on UI frameworks
/// and strictly conforms to ADR-002.
nonisolated struct DeterministicReceiptParser: ReceiptParser, Sendable {

    init() {}

    func parse(lines: [String], currency: Currency) -> ParsedReceiptCandidate {
        var merchantName: String?
        var items: [ParsedReceiptItemCandidate] = []
        var detectedSubtotal: Money?
        var detectedTax: Money?
        var detectedSuggestedTip: Money?
        var detectedTipPercentage: Int?
        var detectedTotal: Money?
        var unclassifiedLines: [String] = []

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            // 1. Noise check: Dividers / separators
            if isSeparator(line) {
                continue
            }

            // 2. Table Column Headers
            if isHeaderLine(line) {
                continue
            }

            // 3. Payment & Change lines
            if isPaymentLine(line) {
                continue
            }

            // 4. Footer greetings
            if isFooterLine(line) {
                continue
            }

            // 5. Lookbehind unit price detail line: e.g. "(2 @ $85.00)" or "2 x $85.00"
            if let detail = parseDetailLine(line, currency: currency) {
                if let lastItem = items.last {
                    let expectedTotal = detail.unitPrice.amountInMinorUnits * Int64(detail.quantity)
                    if lastItem.lineTotal.amountInMinorUnits == expectedTotal {
                        let updated = ParsedReceiptItemCandidate(
                            id: lastItem.id,
                            name: lastItem.name,
                            quantity: detail.quantity,
                            unitPrice: detail.unitPrice,
                            sourceLineText: "\(lastItem.sourceLineText) | \(line)"
                        )
                        items[items.count - 1] = updated
                        continue
                    }
                }
            }

            // 6. Metadata (Ticket numbers, dates, addresses) - checked before summaries to avoid false keyword matches
            if isMetadataLine(line) {
                continue
            }

            // 7. Summary Lines: Subtotal, Tax, Tip, Total
            if let summaryMatch = parseSummaryLine(line, currency: currency) {
                switch summaryMatch {
                case .subtotal(let money):
                    if detectedSubtotal == nil {
                        detectedSubtotal = money
                    }
                case .tax(let money):
                    if detectedTax == nil {
                        detectedTax = money
                    }
                case .tip(let money, let percentage):
                    if detectedSuggestedTip == nil {
                        detectedSuggestedTip = money
                        detectedTipPercentage = percentage
                    }
                case .total(let money):
                    if detectedTotal == nil {
                        detectedTotal = money
                    }
                }
                continue
            }

            // 8. Dish Item line with trailing price
            if let itemMatch = parseDishLine(line, currency: currency) {
                items.append(itemMatch)
                continue
            }

            // 9. Merchant name candidate: First clean descriptive text before items
            if merchantName == nil && items.isEmpty && isValidMerchantName(line) {
                merchantName = line
                continue
            }

            // 10. Otherwise, unclassified line
            unclassifiedLines.append(line)
        }

        // Calculate reconciliation diagnostic
        let computedSubtotalMinor = items.reduce(Int64(0)) { $0 + $1.lineTotal.amountInMinorUnits }
        let computedItemsSubtotal = Money(amountInMinorUnits: computedSubtotalMinor, currency: currency)

        let diagnostic = makeDiagnostic(
            currency: currency,
            items: items,
            computedItemsSubtotal: computedItemsSubtotal,
            detectedSubtotal: detectedSubtotal,
            detectedTax: detectedTax,
            detectedTotal: detectedTotal
        )

        return ParsedReceiptCandidate(
            currency: currency,
            merchantName: merchantName,
            items: items,
            detectedSubtotal: detectedSubtotal,
            detectedTax: detectedTax,
            detectedSuggestedTip: detectedSuggestedTip,
            detectedTipPercentage: detectedTipPercentage,
            detectedTotal: detectedTotal,
            unclassifiedLines: unclassifiedLines,
            reconciliation: diagnostic
        )
    }

    // MARK: - Noise Detection

    private func isSeparator(_ line: String) -> Bool {
        let chars = line.replacingOccurrences(of: " ", with: "")
        guard chars.count >= 3 else { return false }
        let separatorChars: Set<Character> = ["-", "=", "*", "_", "~", ".", "—", "•"]
        return chars.allSatisfy { separatorChars.contains($0) }
    }

    private func isHeaderLine(_ line: String) -> Bool {
        let normalized = normalize(line)
        if normalized.contains("DESCRIPCION") && (normalized.contains("IMPORTE") || normalized.contains("PRECIO")) {
            return true
        }
        if normalized.contains("CANT") && normalized.contains("IMPORTE") {
            return true
        }
        if normalized.contains("ARTICULO") && normalized.contains("IMPORTE") {
            return true
        }
        if normalized == "DESCRIPCION" || normalized == "IMPORTE" || normalized == "CANT" {
            return true
        }
        return false
    }

    private func isPaymentLine(_ line: String) -> Bool {
        let normalized = normalize(line)
        let paymentKeywords = [
            "EFECTIVO", "CAMBIO", "TARJETA", "VISA", "MASTERCARD", "AMEX",
            "VOUCHER", "TRANSACCION", "APROBACION", "DEBITO", "CREDITO"
        ]
        return paymentKeywords.contains { normalized.contains($0) }
    }

    private func isFooterLine(_ line: String) -> Bool {
        let normalized = normalize(line)
        let footerKeywords = [
            "GRACIAS POR SU", "GRACIAS POR TU", "VUELVA PRONTO",
            "ESTE NO ES UN COMPROBANTE", "FACTURACION", "PROPINA NO INCLUIDA"
        ]
        return footerKeywords.contains { normalized.contains($0) }
    }

    private func isMetadataLine(_ line: String) -> Bool {
        let normalized = normalize(line)
        let metadataKeywords = [
            "TICKET #", "TICKET#", "FOLIO", "FECHA:", "HORA:", "FECHA ",
            "ORDEN #", "MESA #", "MESERO", "TERMINAL", "RFC:", "REGIMEN",
            "DOMICILIO", "SUCURSAL", "TEL:", "TELEFONO", "C.P."
        ]
        if metadataKeywords.contains(where: { normalized.contains($0) }) {
            return true
        }

        let addressKeywords = [
            "AV. ", "AVENIDA ", "CALLE ", "PASEO DE ", "BLVD", "COL. ", "COLONIA ", "CDMX", "ROMA NORTE", "INSURGENTES"
        ]
        if addressKeywords.contains(where: { normalized.contains($0) }) {
            return true
        }

        return false
    }

    // MARK: - Detail Line (Lookbehind)

    private struct DetailMatch {
        let quantity: Int
        let unitPrice: Money
    }

    private func parseDetailLine(_ line: String, currency: Currency) -> DetailMatch? {
        let pattern = #"^\s*\(?\s*(\d{1,3})\s*(?:@|[xX]|\ba\b)\s*\$?\s*([0-9]{1,3}(?:,[0-9]{3})*|[0-9]+)(?:\.([0-9]{1,2}))?\s*\)?\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsLine = line as NSString
        guard let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) else {
            return nil
        }

        let qtyString = nsLine.substring(with: match.range(at: 1))
        guard let quantity = Int(qtyString), quantity >= 1 else { return nil }

        // Extract the price component
        let intPart = nsLine.substring(with: match.range(at: 2))
        let fracPart: String
        if match.numberOfRanges > 3 && match.range(at: 3).location != NSNotFound {
            fracPart = "." + nsLine.substring(with: match.range(at: 3))
        } else {
            fracPart = ""
        }
        let fullPriceString = intPart + fracPart

        guard let unitPrice = MoneyParser.parseMajorUnits(from: fullPriceString, currency: currency) else {
            return nil
        }

        return DetailMatch(quantity: quantity, unitPrice: unitPrice)
    }

    // MARK: - Summary Lines

    private enum SummaryMatch {
        case subtotal(Money)
        case tax(Money)
        case tip(Money, Int?)
        case total(Money)
    }

    private func matchesWordPattern(_ patterns: [String], in text: String) -> Bool {
        for pat in patterns {
            let regexPattern = #"(?:\b|^)"# + pat + #"(?:\b|$)"#
            if let regex = try? NSRegularExpression(pattern: regexPattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: (text as NSString).length)
                if regex.firstMatch(in: text, range: range) != nil {
                    return true
                }
            }
        }
        return false
    }

    private func parseSummaryLine(_ line: String, currency: Currency) -> SummaryMatch? {
        let normalized = normalize(line)

        // Subtotal (must be checked before TOTAL)
        if matchesWordPattern(["SUBTOTAL", "SUB-TOTAL", #"SUB\s+TOTAL"#, "CONSUMO"], in: normalized) {
            if let money = extractPrice(from: line, currency: currency) {
                return .subtotal(money)
            }
        }

        // Tax / IVA (using strict word patterns so words like "VIVA" or "VISITA" never match)
        if matchesWordPattern(["IVA", #"I\.V\.A\.?"#, "TAX", "IMPUESTO", "IMPUESTOS"], in: normalized) {
            if let money = extractPrice(from: line, currency: currency) {
                return .tax(money)
            }
        }

        // Tip / Propina
        if matchesWordPattern([#"PROPINA\s+SUGERIDA"#, "PROPINA", #"SUGGESTED\s+TIP"#, "TIP", "SERVICIO"], in: normalized) {
            if let money = extractPrice(from: line, currency: currency) {
                let pct = extractPercentage(from: line)
                return .tip(money, pct)
            }
        }

        // Grand Total (make sure it doesn't match SUBTOTAL)
        if matchesWordPattern(["TOTAL", #"GRAN\s+TOTAL"#, #"TOTAL\s+A\s+PAGAR"#, #"MONTO\s+TOTAL"#], in: normalized)
            && !matchesWordPattern(["SUBTOTAL", "SUB-TOTAL", #"SUB\s+TOTAL"#], in: normalized) {
            if let money = extractPrice(from: line, currency: currency) {
                return .total(money)
            }
        }

        return nil
    }

    // MARK: - Dish Item Line Parsing

    private func parseDishLine(_ line: String, currency: Currency) -> ParsedReceiptItemCandidate? {
        // Line must end with a monetary price
        let pattern = #"^(.*?)(?:\s+\$|\s+)([0-9]{1,3}(?:,[0-9]{3})*|[0-9]+)(?:\.([0-9]{1,2}))?\s*(?:MXN|USD)?\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsLine = line as NSString
        guard let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) else {
            return nil
        }

        let nameCandidate = nsLine.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nameCandidate.isEmpty else { return nil }

        let intPart = nsLine.substring(with: match.range(at: 2))
        let fracPart: String
        if match.numberOfRanges > 3 && match.range(at: 3).location != NSNotFound {
            fracPart = "." + nsLine.substring(with: match.range(at: 3))
        } else {
            fracPart = ""
        }
        let fullPriceString = intPart + fracPart

        guard let lineTotal = MoneyParser.parseMajorUnits(from: fullPriceString, currency: currency) else {
            return nil
        }

        // Check for quantity prefixes: "2x Tacos", "2 x Tacos", "2 Tacos"
        let (quantity, cleanName) = extractQuantityPrefix(from: nameCandidate)

        if quantity > 1 {
            // Integer division rule: only divide if exactly divisible in minor units to avoid losing cents
            if lineTotal.amountInMinorUnits % Int64(quantity) == 0 {
                let unitAmount = lineTotal.amountInMinorUnits / Int64(quantity)
                let unitPrice = Money(amountInMinorUnits: unitAmount, currency: currency)
                return ParsedReceiptItemCandidate(
                    name: cleanName,
                    quantity: quantity,
                    unitPrice: unitPrice,
                    sourceLineText: line
                )
            } else {
                // Non-divisible promo: keep quantity 1 to preserve exact minor units
                return ParsedReceiptItemCandidate(
                    name: nameCandidate,
                    quantity: 1,
                    unitPrice: lineTotal,
                    sourceLineText: line
                )
            }
        } else {
            return ParsedReceiptItemCandidate(
                name: cleanName,
                quantity: 1,
                unitPrice: lineTotal,
                sourceLineText: line
            )
        }
    }

    private func extractQuantityPrefix(from text: String) -> (quantity: Int, cleanName: String) {
        // Pattern 1: "2x Description" or "2 x Description"
        let xPattern = #"^(\d{1,3})\s*[xX]\s*(.+)$"#
        if let regex = try? NSRegularExpression(pattern: xPattern) {
            let nsText = text as NSString
            if let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)) {
                let qtyStr = nsText.substring(with: match.range(at: 1))
                let nameStr = nsText.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                if let q = Int(qtyStr), q >= 1, !nameStr.isEmpty {
                    return (q, nameStr)
                }
            }
        }

        // Pattern 2: "2 Description" (must be followed by letters to avoid phone/date numbers)
        let spacePattern = #"^(\d{1,3})\s+(\p{L}.+)$"#
        if let regex = try? NSRegularExpression(pattern: spacePattern) {
            let nsText = text as NSString
            if let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)) {
                let qtyStr = nsText.substring(with: match.range(at: 1))
                let nameStr = nsText.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                if let q = Int(qtyStr), q >= 1, !nameStr.isEmpty {
                    return (q, nameStr)
                }
            }
        }

        return (1, text)
    }

    // MARK: - Price & Percentage Extraction Helpers

    private func extractPrice(from text: String, currency: Currency) -> Money? {
        // Strip out percentage patterns like (10%) or 15% so their numbers are not confused with price amounts
        var sanitized = text.replacingOccurrences(of: #"\s*\(\s*\d{1,2}\s*%\s*\)"#, with: "", options: .regularExpression)
        sanitized = sanitized.replacingOccurrences(of: #"\d{1,2}\s*%"#, with: "", options: .regularExpression)

        let pattern = #"\$?\s*([0-9]{1,3}(?:,[0-9]{3})*|[0-9]+)(?:\.([0-9]{1,2}))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsText = sanitized as NSString
        let matches = regex.matches(in: sanitized, range: NSRange(location: 0, length: nsText.length))
        guard let lastMatch = matches.last else { return nil }

        let intPart = nsText.substring(with: lastMatch.range(at: 1))
        let fracPart: String
        if lastMatch.numberOfRanges > 2 && lastMatch.range(at: 2).location != NSNotFound {
            fracPart = "." + nsText.substring(with: lastMatch.range(at: 2))
        } else {
            fracPart = ""
        }
        let fullPrice = intPart + fracPart
        return MoneyParser.parseMajorUnits(from: fullPrice, currency: currency)
    }

    private func extractPercentage(from text: String) -> Int? {
        let pattern = #"(\d{1,2})\s*%"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsText = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)) else {
            return nil
        }
        let pctString = nsText.substring(with: match.range(at: 1))
        return Int(pctString)
    }

    private func isValidMerchantName(_ line: String) -> Bool {
        guard line.count >= 3 else { return false }
        guard line.contains(where: { $0.isLetter }) else { return false }
        guard !line.contains("$") else { return false }
        return true
    }

    private func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).uppercased()
    }

    // MARK: - Reconciliation Diagnostic Maker

    private func makeDiagnostic(
        currency: Currency,
        items: [ParsedReceiptItemCandidate],
        computedItemsSubtotal: Money,
        detectedSubtotal: Money?,
        detectedTax: Money?,
        detectedTotal: Money?
    ) -> ReceiptReconciliationDiagnostic {
        guard !items.isEmpty else {
            return ReceiptReconciliationDiagnostic(
                currency: currency,
                computedItemsSubtotal: computedItemsSubtotal,
                detectedSubtotal: detectedSubtotal,
                detectedTax: detectedTax,
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
            let taxMinor = detectedTax?.amountInMinorUnits ?? 0
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
            detectedTax: detectedTax,
            detectedTotal: detectedTotal,
            status: status,
            subtotalMatches: subtotalMatches,
            totalMatches: totalMatches
        )
    }
}
