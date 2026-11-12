import Foundation

// MARK: - DTOs para POST /v1/receipts/parse-ai

nonisolated struct AIParseReceiptRequestDTO: Codable, Sendable {
    let rawText: String
    let currency: String
    let userConsentConfirmed: Bool

    nonisolated init(rawText: String, currency: String, userConsentConfirmed: Bool) {
        self.rawText = rawText
        self.currency = currency
        self.userConsentConfirmed = userConsentConfirmed
    }
}

nonisolated struct AIParseReceiptItemDTO: Codable, Sendable, Equatable {
    let name: String
    let quantity: Int
    let priceCents: Int64

    nonisolated init(
        name: String,
        quantity: Int,
        priceCents: Int64
    ) {
        self.name = name
        self.quantity = quantity
        self.priceCents = priceCents
    }
}

nonisolated struct AIParseReceiptReconciliationDTO: Codable, Sendable, Equatable {
    let status: String
    let computedItemsSubtotalCents: Int64
    let differenceInMinorUnits: Int64
    let subtotalMatches: Bool?
    let totalMatches: Bool?

    nonisolated init(
        status: String,
        computedItemsSubtotalCents: Int64,
        differenceInMinorUnits: Int64,
        subtotalMatches: Bool?,
        totalMatches: Bool?
    ) {
        self.status = status
        self.computedItemsSubtotalCents = computedItemsSubtotalCents
        self.differenceInMinorUnits = differenceInMinorUnits
        self.subtotalMatches = subtotalMatches
        self.totalMatches = totalMatches
    }
}

nonisolated struct AIParseReceiptResponseDTO: Codable, Sendable {
    let providerUsed: String
    let fallbackUsed: Bool?
    let merchantName: String?
    let date: String?
    let currency: String
    let subtotalCents: Int64?
    let taxCents: Int64?
    let tipCents: Int64?
    let totalCents: Int64?
    let items: [AIParseReceiptItemDTO]
    let reconciliation: AIParseReceiptReconciliationDTO?

    nonisolated init(
        providerUsed: String,
        fallbackUsed: Bool? = false,
        merchantName: String? = nil,
        date: String? = nil,
        currency: String = "MXN",
        subtotalCents: Int64? = nil,
        taxCents: Int64? = nil,
        tipCents: Int64? = nil,
        totalCents: Int64? = nil,
        items: [AIParseReceiptItemDTO] = [],
        reconciliation: AIParseReceiptReconciliationDTO? = nil
    ) {
        self.providerUsed = providerUsed
        self.fallbackUsed = fallbackUsed
        self.merchantName = merchantName
        self.date = date
        self.currency = currency
        self.subtotalCents = subtotalCents
        self.taxCents = taxCents
        self.tipCents = tipCents
        self.totalCents = totalCents
        self.items = items
        self.reconciliation = reconciliation
    }
}

// MARK: - Origen de la Extracción

enum ExtractionSource: Equatable, Hashable, Sendable {
    case deterministic
    case aiProxy(provider: String)

    var displayName: String {
        switch self {
        case .deterministic:
            return "Motor Local (En dispositivo)"
        case .aiProxy(let provider):
            if provider == "heuristic-fallback" {
                return "Respaldo Local (Sin conexión)"
            }
            return "Asistido por IA (\(provider))"
        }
    }

    var isAI: Bool {
        switch self {
        case .deterministic:
            return false
        case .aiProxy(let provider):
            return provider != "heuristic-fallback"
        }
    }
}

// MARK: - Errores Tipados

enum AIReceiptParserError: Error, Equatable, Sendable, LocalizedError {
    case consentRequired
    case emptyText
    case networkUnavailable
    case serverError(statusCode: Int, message: String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .consentRequired:
            return "Se requiere el consentimiento informado antes de enviar datos del recibo a la IA."
        case .emptyText:
            return "No hay texto para procesar. Extrae primero el texto con OCR."
        case .networkUnavailable:
            return "No se pudo conectar con el servidor de SplitBill. Comprueba tu conexión a internet."
        case .serverError(let statusCode, let message):
            return "Error en el servidor (\(statusCode)): \(message)"
        case .invalidResponse:
            return "La respuesta del servidor no tiene un formato válido."
        }
    }
}
