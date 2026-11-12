import Foundation

/// Contrato para el servicio de análisis inteligente de tickets vía IA.
nonisolated protocol AIReceiptParserService: Sendable {
    func parseReceiptWithAI(
        rawText: String,
        currency: Currency,
        userConsentConfirmed: Bool
    ) async throws(AIReceiptParserError) -> (candidate: ParsedReceiptCandidate, providerUsed: String)
}

/// Implementación cliente HTTP que consume el proxy `POST /v1/receipts/parse-ai`.
nonisolated final class HTTPProxyAIReceiptParserService: AIReceiptParserService, Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let devUserId: String?
    private let allowLocalFallback: Bool
    private let localFallbackParser: any ReceiptParser

    nonisolated init(
        baseURL: URL? = nil,
        session: URLSession? = nil,
        devUserId: String? = "dev-user-ios",
        allowLocalFallback: Bool = true,
        localFallbackParser: any ReceiptParser = DeterministicReceiptParser()
    ) {
        if let baseURL {
            self.baseURL = baseURL
        } else if let envUrlString = ProcessInfo.processInfo.environment["SPLITBILL_API_URL"],
                  let envUrl = URL(string: envUrlString) {
            self.baseURL = envUrl
        } else if let defaultURL = URL(string: "http://127.0.0.1:3000") {
            self.baseURL = defaultURL
        } else {
            preconditionFailure("Invalid default API URL string")
        }

        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 30
            self.session = URLSession(configuration: config)
        }

        self.devUserId = devUserId
        self.allowLocalFallback = allowLocalFallback
        self.localFallbackParser = localFallbackParser
    }

    func parseReceiptWithAI(
        rawText: String,
        currency: Currency,
        userConsentConfirmed: Bool
    ) async throws(AIReceiptParserError) -> (candidate: ParsedReceiptCandidate, providerUsed: String) {
        guard userConsentConfirmed else {
            throw .consentRequired
        }

        let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw .emptyText
        }

        let endpoint = baseURL.appendingPathComponent("v1/receipts/parse-ai")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let devUserId {
            request.setValue(devUserId, forHTTPHeaderField: "x-dev-user-id")
        }

        let requestDTO = AIParseReceiptRequestDTO(
            rawText: trimmedText,
            currency: currency.code,
            userConsentConfirmed: true
        )

        do {
            request.httpBody = try JSONEncoder().encode(requestDTO)
        } catch {
            throw .invalidResponse
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if allowLocalFallback {
                let fallback = localFallbackParser.parse(rawText: trimmedText, currency: currency)
                return (candidate: fallback, providerUsed: "heuristic-fallback")
            }
            throw .networkUnavailable
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            if allowLocalFallback {
                let fallback = localFallbackParser.parse(rawText: trimmedText, currency: currency)
                return (candidate: fallback, providerUsed: "heuristic-fallback")
            }
            throw .invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if allowLocalFallback {
                let fallback = localFallbackParser.parse(rawText: trimmedText, currency: currency)
                return (candidate: fallback, providerUsed: "heuristic-fallback")
            }
            let serverMessage = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw .serverError(statusCode: httpResponse.statusCode, message: serverMessage)
        }

        let responseDTO: AIParseReceiptResponseDTO
        do {
            responseDTO = try JSONDecoder().decode(AIParseReceiptResponseDTO.self, from: data)
        } catch {
            if allowLocalFallback {
                let fallback = localFallbackParser.parse(rawText: trimmedText, currency: currency)
                return (candidate: fallback, providerUsed: "heuristic-fallback")
            }
            throw .invalidResponse
        }

        let candidate = Self.mapToCandidate(dto: responseDTO, currency: currency)
        return (candidate: candidate, providerUsed: responseDTO.providerUsed)
    }

    static func mapToCandidate(
        dto: AIParseReceiptResponseDTO,
        currency: Currency
    ) -> ParsedReceiptCandidate {
        let items: [ParsedReceiptItemCandidate] = dto.items.map { itemDTO in
            ParsedReceiptItemCandidate(
                id: UUID(),
                name: itemDTO.name,
                quantity: max(1, itemDTO.quantity),
                unitPrice: Money(amountInMinorUnits: itemDTO.priceCents, currency: currency),
                sourceLineText: itemDTO.name
            )
        }

        let detectedSubtotal = dto.subtotalCents.map {
            Money(amountInMinorUnits: $0, currency: currency)
        }
        let detectedTax = dto.taxCents.map {
            Money(amountInMinorUnits: $0, currency: currency)
        }
        let detectedSuggestedTip = dto.tipCents.map {
            Money(amountInMinorUnits: $0, currency: currency)
        }
        let detectedTotal = dto.totalCents.map {
            Money(amountInMinorUnits: $0, currency: currency)
        }

        let diagnostic = makeDiagnostic(
            currency: currency,
            items: items,
            detectedSubtotal: detectedSubtotal,
            detectedTax: detectedTax,
            detectedTotal: detectedTotal
        )

        return ParsedReceiptCandidate(
            currency: currency,
            merchantName: dto.merchantName,
            items: items,
            detectedSubtotal: detectedSubtotal,
            detectedTax: detectedTax,
            detectedSuggestedTip: detectedSuggestedTip,
            detectedTipPercentage: nil,
            detectedTotal: detectedTotal,
            unclassifiedLines: [],
            reconciliation: diagnostic
        )
    }

    private static func makeDiagnostic(
        currency: Currency,
        items: [ParsedReceiptItemCandidate],
        detectedSubtotal: Money?,
        detectedTax: Money?,
        detectedTotal: Money?
    ) -> ReceiptReconciliationDiagnostic {
        let computedItemsSubtotalMinor = items.reduce(Int64(0)) { $0 + $1.lineTotal.amountInMinorUnits }
        let computedItemsSubtotal = Money(amountInMinorUnits: computedItemsSubtotalMinor, currency: currency)

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

        let subtotalMatches: Bool? = detectedSubtotal.map { $0 == computedItemsSubtotal }

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
