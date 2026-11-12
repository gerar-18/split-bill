import Foundation
import Testing
@testable import SplitBill

@Suite("AI Receipt Parsing & Consent Tests")
@MainActor
struct AIReceiptParsingTests {

    // MARK: - Mocks

    final class MockAIService: AIReceiptParserService, @unchecked Sendable {
        var parseCallCount = 0
        var shouldThrow: AIReceiptParserError? = nil
        var mockResult: (candidate: ParsedReceiptCandidate, providerUsed: String)? = nil

        func parseReceiptWithAI(
            rawText: String,
            currency: Currency,
            userConsentConfirmed: Bool
        ) async throws(AIReceiptParserError) -> (candidate: ParsedReceiptCandidate, providerUsed: String) {
            parseCallCount += 1
            guard userConsentConfirmed else {
                throw .consentRequired
            }
            if let shouldThrow {
                throw shouldThrow
            }
            if let mockResult {
                return mockResult
            }

            let candidate = DeterministicReceiptParser().parse(rawText: rawText, currency: currency)
            return (candidate: candidate, providerUsed: "mock-llm")
        }
    }

    // MARK: - Tests

    @Test("Opening AI parser without prior consent shows consent sheet and triggers zero network requests")
    func requiresConsentBeforeNetworkCall() async {
        let consentStore = InMemoryAIConsentStore(hasGrantedConsent: false)
        let aiService = MockAIService()
        let vm = ReceiptEditorViewModel(
            aiParserService: aiService,
            aiConsentStore: consentStore
        )

        // Attach sample image
        vm.attachSampleReceipt(.taqueriaElPastor)
        await vm.recognizeReceiptText()

        #expect(vm.hasGrantedAIConsent == false)
        #expect(vm.isShowingAIConsentSheet == false)

        await vm.requestAIReceiptParsing()

        #expect(vm.isShowingAIConsentSheet == true)
        #expect(aiService.parseCallCount == 0)
    }

    @Test("Granting consent updates store, closes sheet, invokes AI service, and prepares review draft")
    func grantConsentAndParseFlow() async throws {
        let consentStore = InMemoryAIConsentStore(hasGrantedConsent: false)
        let aiService = MockAIService()

        let item1 = ParsedReceiptItemCandidate(
            name: "Tacos al Pastor",
            quantity: 2,
            unitPrice: Money(amountInMinorUnits: 4500, currency: .mxn),
            sourceLineText: "2 Tacos al Pastor $90.00"
        )
        let diag = ReceiptReconciliationDiagnostic(
            currency: .mxn,
            computedItemsSubtotal: Money(amountInMinorUnits: 9000, currency: .mxn),
            detectedSubtotal: Money(amountInMinorUnits: 9000, currency: .mxn),
            detectedTax: nil,
            detectedTotal: Money(amountInMinorUnits: 9000, currency: .mxn),
            status: .verified,
            subtotalMatches: true,
            totalMatches: true
        )
        let candidate = ParsedReceiptCandidate(
            currency: .mxn,
            merchantName: "Taquería El Pastor",
            items: [item1],
            detectedSubtotal: Money(amountInMinorUnits: 9000, currency: .mxn),
            detectedTax: nil,
            detectedSuggestedTip: nil,
            detectedTipPercentage: nil,
            detectedTotal: Money(amountInMinorUnits: 9000, currency: .mxn),
            unclassifiedLines: [],
            reconciliation: diag
        )
        aiService.mockResult = (candidate: candidate, providerUsed: "deepseek-chat")

        let vm = ReceiptEditorViewModel(
            aiParserService: aiService,
            aiConsentStore: consentStore
        )
        vm.attachSampleReceipt(.taqueriaElPastor)
        await vm.recognizeReceiptText()

        await vm.grantAIConsentAndParse()

        #expect(consentStore.hasGrantedConsent == true)
        #expect(consentStore.consentTimestamp != nil)
        #expect(vm.hasGrantedAIConsent == true)
        #expect(vm.isShowingAIConsentSheet == false)
        #expect(aiService.parseCallCount == 1)
        #expect(vm.lastExtractionSource == .aiProxy(provider: "deepseek-chat"))
        #expect(vm.parsedCandidate?.items.count == 1)
        #expect(vm.parsedReviewDraft != nil)
        #expect(vm.isShowingParsedReviewSheet == true)
    }

    @Test("Revoking consent clears persistent consent and timestamp")
    func revokingConsent() {
        let consentStore = InMemoryAIConsentStore(hasGrantedConsent: true, consentTimestamp: Date())
        let vm = ReceiptEditorViewModel(aiConsentStore: consentStore)

        #expect(vm.hasGrantedAIConsent == true)
        vm.revokeAIConsent()
        #expect(vm.hasGrantedAIConsent == false)
        #expect(consentStore.hasGrantedConsent == false)
        #expect(consentStore.consentTimestamp == nil)
    }

    @Test("Reconciliation computes exact discrepancy when AI items do not equal detected total")
    func reconciliationExactDiscrepancy() {
        let dto = AIParseReceiptResponseDTO(
            providerUsed: "deepseek-chat",
            merchantName: "Bistro 101",
            currency: "MXN",
            subtotalCents: 15_000,
            taxCents: 2_400,
            tipCents: nil,
            totalCents: 20_000, // Expected 17,400 -> discrepancy +2,600
            items: [
                AIParseReceiptItemDTO(
                    name: "Hamburguesa",
                    quantity: 1,
                    priceCents: 15_000
                )
            ]
        )

        let candidate = HTTPProxyAIReceiptParserService.mapToCandidate(dto: dto, currency: .mxn)
        #expect(candidate.reconciliation.status == .discrepancy(differenceInMinorUnits: 2_600, currency: .mxn))
        #expect(candidate.reconciliation.totalMatches == false)
        #expect(candidate.reconciliation.subtotalMatches == true)
    }

    @Test("Protects against actor reentrancy when receipt session changes during AI request")
    func actorReentrancyProtection() async {
        let consentStore = InMemoryAIConsentStore(hasGrantedConsent: true)
        let aiService = MockAIService()
        let vm = ReceiptEditorViewModel(
            aiParserService: aiService,
            aiConsentStore: consentStore
        )

        vm.attachSampleReceipt(.taqueriaElPastor)
        await vm.recognizeReceiptText()

        // Launch slow parsing task in background
        let parseTask = Task {
            await vm.requestAIReceiptParsing()
        }

        // Before it completes, switch receipt session
        vm.startNewReceipt()

        await parseTask.value

        // Candidate must not be set on new receipt
        #expect(vm.parsedCandidate == nil)
        #expect(vm.isShowingParsedReviewSheet == false)
    }

    @Test("Fallback to deterministic parser when network fails and fallback is enabled")
    func fallbackOnNetworkFailure() async throws {
        let localParser = DeterministicReceiptParser()
        let client = HTTPProxyAIReceiptParserService(
            baseURL: URL(string: "http://127.0.0.1:9999")!, // offline port
            allowLocalFallback: true,
            localFallbackParser: localParser
        )

        let sampleText = """
        Taquería San Juan
        2 Tacos al Pastor $90.00
        Total: $90.00
        """

        let result = try await client.parseReceiptWithAI(
            rawText: sampleText,
            currency: .mxn,
            userConsentConfirmed: true
        )

        #expect(result.providerUsed == "heuristic-fallback")
        #expect(result.candidate.items.count == 1)
        #expect(result.candidate.items.first?.name == "Tacos al Pastor")
    }

    @Test("UserDefaultsAIConsentStore lifecycle: grant, persist and revoke")
    func userDefaultsConsentStoreLifecycle() {
        let suiteName = "test.splitbill.consent.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsAIConsentStore(userDefaults: defaults)

        #expect(store.hasGrantedConsent == false)
        #expect(store.consentTimestamp == nil)

        store.grantConsent()
        #expect(store.hasGrantedConsent == true)
        #expect(store.consentTimestamp != nil)

        // Recreate store with same defaults to verify persistence
        let reloadedStore = UserDefaultsAIConsentStore(userDefaults: defaults)
        #expect(reloadedStore.hasGrantedConsent == true)
        #expect(reloadedStore.consentTimestamp != nil)

        reloadedStore.revokeConsent()
        #expect(reloadedStore.hasGrantedConsent == false)
        #expect(reloadedStore.consentTimestamp == nil)
    }

    @Test("AI DTOs encode and decode cleanly without loss of cents precision")
    func dtosCodableRoundtrip() throws {
        let request = AIParseReceiptRequestDTO(
            rawText: "Ticket 120.50",
            currency: "USD",
            userConsentConfirmed: true
        )
        let requestData = try JSONEncoder().encode(request)
        let decodedRequest = try JSONDecoder().decode(AIParseReceiptRequestDTO.self, from: requestData)
        #expect(decodedRequest.rawText == "Ticket 120.50")
        #expect(decodedRequest.currency == "USD")
        #expect(decodedRequest.userConsentConfirmed == true)

        let response = AIParseReceiptResponseDTO(
            providerUsed: "deepseek-chat",
            fallbackUsed: false,
            merchantName: "Cafe",
            date: "2026-11-12",
            currency: "USD",
            subtotalCents: 12050,
            taxCents: 1200,
            tipCents: 1000,
            totalCents: 14250,
            items: [
                AIParseReceiptItemDTO(name: "Coffee", quantity: 2, priceCents: 6025)
            ]
        )
        let responseData = try JSONEncoder().encode(response)
        let decodedResponse = try JSONDecoder().decode(AIParseReceiptResponseDTO.self, from: responseData)
        #expect(decodedResponse.providerUsed == "deepseek-chat")
        #expect(decodedResponse.subtotalCents == 12050)
        #expect(decodedResponse.items.count == 1)
        #expect(decodedResponse.items[0].priceCents == 6025)
    }

    @Test("ExtractionSource classifies fallback as non-AI local backup for UI transparency")
    func extractionSourceClassification() {
        let deterministic = ExtractionSource.deterministic
        #expect(deterministic.isAI == false)
        #expect(deterministic.displayName == "Motor Local (En dispositivo)")

        let aiSource = ExtractionSource.aiProxy(provider: "deepseek-chat")
        #expect(aiSource.isAI == true)
        #expect(aiSource.displayName == "Asistido por IA (deepseek-chat)")

        let fallbackSource = ExtractionSource.aiProxy(provider: "heuristic-fallback")
        #expect(fallbackSource.isAI == false)
        #expect(fallbackSource.displayName == "Respaldo Local (Sin conexión)")
    }
}
