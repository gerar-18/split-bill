import Foundation
import CoreGraphics
import Testing
@testable import SplitBill

@Suite("ReceiptEditorViewModel Parsing & Review Tests")
@MainActor
struct ReceiptEditorViewModelParsingTests {

    private final class MockOCRService: ReceiptOCRService, @unchecked Sendable {
        let result: ReceiptOCRResult

        init(result: ReceiptOCRResult) {
            self.result = result
        }

        func recognizeText(from imageData: Data) async throws(ReceiptOCRError) -> ReceiptOCRResult {
            result
        }
    }

    // MARK: - 1. recognizeReceiptText Populates parsedCandidate

    @Test("recognizeReceiptText populates parsedCandidate upon OCR completion")
    func recognizeReceiptTextPopulatesCandidate() async {
        let lines = [
            ReceiptOCRLine(
                text: "TAQUERÍA LOS REYES",
                tokens: [],
                confidence: 0.95,
                boundingBox: .zero
            ),
            ReceiptOCRLine(
                text: "2 TACOS AL PASTOR $170.00",
                tokens: [],
                confidence: 0.95,
                boundingBox: .zero
            ),
            ReceiptOCRLine(
                text: "TOTAL $170.00",
                tokens: [],
                confidence: 0.98,
                boundingBox: .zero
            )
        ]
        let mockOCR = MockOCRService(
            result: ReceiptOCRResult(
                lines: lines,
                rawText: lines.map(\.text).joined(separator: "\n"),
                averageConfidence: 0.96
            )
        )

        let vm = ReceiptEditorViewModel(ocrService: mockOCR)
        vm.receiptImageData = Data([0x01, 0x02, 0x03])

        #expect(vm.parsedCandidate == nil)
        await vm.recognizeReceiptText()

        #expect(vm.lastOCRResult != nil)
        #expect(vm.parsedCandidate != nil)
        #expect(vm.parsedCandidate?.merchantName == "TAQUERÍA LOS REYES")
        #expect(vm.parsedCandidate?.items.count == 1)
        #expect(vm.parsedCandidate?.items.first?.name == "TACOS AL PASTOR")
        #expect(vm.parsedCandidate?.items.first?.quantity == 2)
        #expect(vm.parsedCandidate?.items.first?.unitPrice == Money(amountInMinorUnits: 8500, currency: .mxn))
        #expect(vm.parsedCandidate?.detectedTotal == Money(amountInMinorUnits: 17000, currency: .mxn))
    }

    // MARK: - 2. prepareParsedReceiptReview Builds Draft and Opens Sheet

    @Test("prepareParsedReceiptReview builds draft and opens sheet")
    func prepareParsedReceiptReviewBuildsDraft() async {
        let rawLines = [
            "PIZZERIA BELLA",
            "1 PIZZA MARGHERITA $220.00",
            "IVA $35.20",
            "TOTAL $255.20"
        ]
        let mockOCR = MockOCRService(
            result: ReceiptOCRResult(
                lines: rawLines.map { ReceiptOCRLine(text: $0, tokens: [], confidence: 1.0, boundingBox: .zero) },
                rawText: rawLines.joined(separator: "\n"),
                averageConfidence: 1.0
            )
        )
        let vm = ReceiptEditorViewModel(ocrService: mockOCR)
        vm.receiptImageData = Data([0x01])

        #expect(vm.parsedReviewDraft == nil)
        #expect(!vm.isShowingParsedReviewSheet)

        await vm.recognizeReceiptText()

        // Trigger prepare
        vm.prepareParsedReceiptReview()

        #expect(vm.isShowingParsedReviewSheet)
        #expect(vm.parsedReviewDraft != nil)
        #expect(vm.parsedReviewDraft?.merchantName == "PIZZERIA BELLA")
        #expect(vm.parsedReviewDraft?.items.count == 1)
        #expect(vm.parsedReviewDraft?.items.first?.name == "PIZZA MARGHERITA")
        #expect(vm.parsedReviewDraft?.includeDetectedTax == true)
        #expect(vm.parsedReviewDraft?.taxText == "35.20")
    }

    // MARK: - 3. confirmParsedReceiptImport Fails if participants.isEmpty

    @Test("confirmParsedReceiptImport fails if participants are empty with descriptive message")
    func confirmImportFailsWithoutParticipants() {
        let parser = DeterministicReceiptParser()
        let candidate = parser.parse(
            lines: [
                "CAFE CENTRAL",
                "1 CAPPUCCINO $65.00",
                "TOTAL $65.00"
            ],
            currency: .mxn
        )

        let vm = ReceiptEditorViewModel()
        #expect(vm.participants.isEmpty)

        vm.parsedReviewDraft = ParsedReceiptReviewDraft(from: candidate)
        vm.isShowingParsedReviewSheet = true

        let success = vm.confirmParsedReceiptImport(replaceExistingItems: false)

        #expect(!success)
        #expect(vm.items.isEmpty)
        #expect(vm.importValidationErrorMessage != nil)
        #expect(vm.importValidationErrorMessage?.localizedCaseInsensitiveContains("comensal") == true)
    }

    // MARK: - 4. confirmParsedReceiptImport Imports Items with .equal, Handles replaceExistingItems, Tax and Tip

    @Test("confirmParsedReceiptImport imports items equally, supports replace toggle, and applies tax and tip")
    func confirmImportFlow() throws {
        let vm = ReceiptEditorViewModel()
        vm.newParticipantName = "Ana"
        vm.addParticipant()
        vm.newParticipantName = "Carlos"
        vm.addParticipant()
        #expect(vm.participants.count == 2)
        let participantIDs = Set(vm.participants.map(\.id))

        let candidate = ParsedReceiptCandidate(
            currency: .mxn,
            merchantName: "BISTRO PARIS",
            items: [
                ParsedReceiptItemCandidate(
                    name: "Sopa de Cebolla",
                    quantity: 2,
                    unitPrice: Money(amountInMinorUnits: 12000, currency: .mxn),
                    sourceLineText: "2 Sopa de Cebolla $240.00"
                )
            ],
            detectedSubtotal: Money(amountInMinorUnits: 24000, currency: .mxn),
            detectedTax: Money(amountInMinorUnits: 3840, currency: .mxn),
            detectedSuggestedTip: Money(amountInMinorUnits: 2400, currency: .mxn),
            detectedTipPercentage: 10,
            detectedTotal: Money(amountInMinorUnits: 27840, currency: .mxn),
            unclassifiedLines: [],
            reconciliation: ReceiptReconciliationDiagnostic(
                currency: .mxn,
                computedItemsSubtotal: Money(amountInMinorUnits: 24000, currency: .mxn),
                detectedSubtotal: Money(amountInMinorUnits: 24000, currency: .mxn),
                detectedTax: Money(amountInMinorUnits: 3840, currency: .mxn),
                detectedTotal: Money(amountInMinorUnits: 27840, currency: .mxn),
                status: .verified,
                subtotalMatches: true,
                totalMatches: true
            )
        )

        vm.parsedReviewDraft = ParsedReceiptReviewDraft(from: candidate)
        vm.isShowingParsedReviewSheet = true

        // 1. Initial import with replaceExistingItems: false
        let success1 = vm.confirmParsedReceiptImport(replaceExistingItems: false)
        #expect(success1)
        #expect(vm.items.count == 1)
        #expect(vm.items.first?.name == "Sopa de Cebolla")
        #expect(vm.items.first?.quantity == 2)
        #expect(vm.items.first?.unitPrice == Money(amountInMinorUnits: 12000, currency: .mxn))
        #expect(vm.items.first?.splitMode == .equal(participantIDs))
        #expect(vm.receiptTitle == "BISTRO PARIS")
        #expect(vm.taxText == "38.40")
        #expect(vm.tipSelection == .custom)
        #expect(vm.customTipText == "24.00")
        #expect(!vm.isShowingParsedReviewSheet)
        #expect(vm.parsedReviewDraft == nil)

        // 2. Second import with replaceExistingItems: false (should append)
        let secondCandidate = ParsedReceiptCandidate(
            currency: .mxn,
            merchantName: "BISTRO PARIS",
            items: [
                ParsedReceiptItemCandidate(
                    name: "Crepa Dulce",
                    quantity: 1,
                    unitPrice: Money(amountInMinorUnits: 9500, currency: .mxn),
                    sourceLineText: "1 Crepa Dulce $95.00"
                )
            ],
            detectedSubtotal: nil,
            detectedTax: nil,
            detectedSuggestedTip: nil,
            detectedTipPercentage: nil,
            detectedTotal: nil,
            unclassifiedLines: [],
            reconciliation: ReceiptReconciliationDiagnostic(
                currency: .mxn,
                computedItemsSubtotal: Money(amountInMinorUnits: 9500, currency: .mxn),
                detectedSubtotal: nil,
                detectedTax: nil,
                detectedTotal: nil,
                status: .partial,
                subtotalMatches: nil,
                totalMatches: nil
            )
        )

        vm.parsedReviewDraft = ParsedReceiptReviewDraft(from: secondCandidate)
        let success2 = vm.confirmParsedReceiptImport(replaceExistingItems: false)
        #expect(success2)
        #expect(vm.items.count == 2)
        #expect(vm.items.map(\.name) == ["Sopa de Cebolla", "Crepa Dulce"])

        // 3. Third import with replaceExistingItems: true (should replace all items)
        vm.parsedReviewDraft = ParsedReceiptReviewDraft(from: secondCandidate)
        let success3 = vm.confirmParsedReceiptImport(replaceExistingItems: true)
        #expect(success3)
        #expect(vm.items.count == 1)
        #expect(vm.items.first?.name == "Crepa Dulce")
    }

    // MARK: - 5. Live Reconciliation Updates in ParsedReceiptReviewDraft

    @Test("ParsedReceiptReviewDraft live reconciliation reflects user edits and toggles")
    func draftLiveReconciliationUpdates() {
        let item1 = EditableParsedItemDraft(
            id: UUID(),
            isIncluded: true,
            name: "Hamburguesa",
            quantity: 1,
            unitPriceText: "150.00",
            sourceLineText: "1 Hamburguesa $150.00"
        )
        let item2 = EditableParsedItemDraft(
            id: UUID(),
            isIncluded: true,
            name: "Papas Fritas",
            quantity: 1,
            unitPriceText: "50.00",
            sourceLineText: "1 Papas Fritas $50.00"
        )

        let draft = ParsedReceiptReviewDraft(
            currency: .mxn,
            merchantName: "Burger Spot",
            items: [item1, item2],
            includeDetectedTax: false,
            taxText: "32.00",
            includeDetectedTip: false,
            tipText: "",
            detectedTotal: Money(amountInMinorUnits: 20000, currency: .mxn),
            detectedSubtotal: Money(amountInMinorUnits: 20000, currency: .mxn),
            unclassifiedLines: []
        )

        // Initial state: subtotal $200.00, detected total $200.00 -> verified
        #expect(draft.computedItemsSubtotal == Money(amountInMinorUnits: 20000, currency: .mxn))
        #expect(draft.reconciliation.status == .verified)
        #expect(draft.reconciliation.subtotalMatches == true)
        #expect(draft.reconciliation.totalMatches == true)

        // User edits item 2 price from $50.00 to $80.00 -> discrepancy
        item2.unitPriceText = "80.00"
        #expect(draft.computedItemsSubtotal == Money(amountInMinorUnits: 23000, currency: .mxn))
        #expect(draft.reconciliation.status == .discrepancy(differenceInMinorUnits: -3000, currency: .mxn))

        // User excludes item 2 -> subtotal becomes $150.00
        item2.isIncluded = false
        #expect(draft.computedItemsSubtotal == Money(amountInMinorUnits: 15000, currency: .mxn))
        #expect(draft.reconciliation.status == .discrepancy(differenceInMinorUnits: 5000, currency: .mxn))

        // User includes tax toggle ($32.00)
        draft.includeDetectedTax = true
        #expect(draft.resolvedTax == Money(amountInMinorUnits: 3200, currency: .mxn))
    }

    // MARK: - 6. Validation Failures and Dismiss Tests

    @Test("confirmParsedReceiptImport fails when all items are excluded or price is zero")
    func confirmImportValidationFailures() {
        let vm = ReceiptEditorViewModel()
        vm.newParticipantName = "Daniel"
        vm.addParticipant()

        let item1 = EditableParsedItemDraft(
            name: "Ensalada",
            quantity: 1,
            unitPriceText: "100.00"
        )
        let draft = ParsedReceiptReviewDraft(
            currency: .mxn,
            items: [item1]
        )
        vm.parsedReviewDraft = draft
        vm.isShowingParsedReviewSheet = true

        // 1. Exclude all items
        item1.isIncluded = false
        #expect(!vm.confirmParsedReceiptImport(replaceExistingItems: false))
        #expect(vm.importValidationErrorMessage?.contains("No hay artículos seleccionados") == true)

        // 2. Invalid price ($0.00)
        item1.isIncluded = true
        item1.unitPriceText = "0.00"
        #expect(!vm.confirmParsedReceiptImport(replaceExistingItems: false))
        #expect(vm.importValidationErrorMessage?.contains("inválido") == true)
    }

    @Test("dismissParsedReceiptReview clears draft and sheet flag")
    func dismissParsedReceiptReviewClearsState() {
        let vm = ReceiptEditorViewModel()
        vm.parsedReviewDraft = ParsedReceiptReviewDraft(currency: .mxn)
        vm.isShowingParsedReviewSheet = true
        vm.importValidationErrorMessage = "Error previo"

        vm.dismissParsedReceiptReview()

        #expect(vm.parsedReviewDraft == nil)
        #expect(!vm.isShowingParsedReviewSheet)
        #expect(vm.importValidationErrorMessage == nil)
    }
}
