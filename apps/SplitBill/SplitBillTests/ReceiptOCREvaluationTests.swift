import Foundation
import CoreGraphics
import Testing
@testable import SplitBill

// MARK: - Test Stub

struct StubReceiptOCRService: ReceiptOCRService, Sendable {
    let resultToReturn: ReceiptOCRResult?
    let errorToThrow: ReceiptOCRError?
    let delay: Duration?

    init(
        resultToReturn: ReceiptOCRResult? = nil,
        errorToThrow: ReceiptOCRError? = nil,
        delay: Duration? = nil
    ) {
        self.resultToReturn = resultToReturn
        self.errorToThrow = errorToThrow
        self.delay = delay
    }

    func recognizeText(from imageData: Data) async throws(ReceiptOCRError) -> ReceiptOCRResult {
        if let delay {
            try? await Task.sleep(for: delay)
        }
        if let errorToThrow {
            throw errorToThrow
        }
        return resultToReturn ?? .empty
    }
}

// MARK: - Persistence & ViewModel Suite

@Suite("Receipt OCR Persistence & ViewModel Tests")
@MainActor
struct ReceiptOCRPersistenceAndViewModelTests {

    @Test("ReceiptSnapshot with ocrRawText round-trips faithfully through SwiftData store")
    func snapshotWithOCRRoundTripsThroughStore() throws {
        let store = try SwiftDataReceiptStore.inMemory()

        let ocrContent = """
        TAQUERÍA EL PASTOR
        2x Tacos al Pastor $170.00
        SUBTOTAL $170.00
        TOTAL $170.00
        """

        var snapshot = ReceiptSnapshot(
            id: UUID(),
            title: "Ticket Taquería",
            currency: .mxn,
            ocrRawText: ocrContent
        )

        try store.save(snapshot)

        let loaded = try #require(try store.fetch(id: snapshot.id))
        #expect(loaded.ocrRawText == ocrContent)
        #expect(loaded.title == "Ticket Taquería")

        // Clearing OCR text and updating persists nil
        snapshot.ocrRawText = nil
        snapshot.updatedAt = Date()
        try store.save(snapshot)

        let reloaded = try #require(try store.fetch(id: snapshot.id))
        #expect(reloaded.ocrRawText == nil)
    }

    @Test("recognizeReceiptText updates ocrRawText, lastOCRResult, and auto-persists to store")
    func recognizeReceiptTextUpdatesStateAndPersists() async throws {
        let store = try SwiftDataReceiptStore.inMemory()

        let line1 = ReceiptOCRLine(
            text: "PIZZERÍA NAPOLI",
            tokens: [],
            confidence: 0.98,
            boundingBox: CGRect(x: 0.1, y: 0.9, width: 0.8, height: 0.05)
        )
        let line2 = ReceiptOCRLine(
            text: "Pizza Margherita $220.00",
            tokens: [],
            confidence: 0.95,
            boundingBox: CGRect(x: 0.1, y: 0.7, width: 0.8, height: 0.04)
        )
        let line3 = ReceiptOCRLine(
            text: "TOTAL $220.00",
            tokens: [],
            confidence: 0.97,
            boundingBox: CGRect(x: 0.1, y: 0.3, width: 0.8, height: 0.04)
        )
        let mockResult = ReceiptOCRResult(
            lines: [line1, line2, line3],
            rawText: "PIZZERÍA NAPOLI\nPizza Margherita $220.00\nTOTAL $220.00",
            averageConfidence: 0.96
        )

        let stub = StubReceiptOCRService(resultToReturn: mockResult)
        let vm = ReceiptEditorViewModel(store: store, ocrService: stub)

        #expect(!vm.hasOCRText)
        #expect(vm.ocrLineCount == 0)

        vm.attachSampleReceipt(.pizzeriaNapoli)
        #expect(vm.receiptImageData != nil)

        await vm.recognizeReceiptText()

        #expect(vm.hasOCRText)
        #expect(vm.ocrLineCount == 3)
        #expect(vm.ocrRawText == mockResult.rawText)
        #expect(vm.lastOCRResult?.lines.count == 3)
        #expect(vm.validationMessage == nil)

        // Verify auto-persisted in SwiftData store
        let persisted = try #require(try store.fetch(id: vm.receiptID))
        #expect(persisted.ocrRawText == mockResult.rawText)
    }

    @Test("recognizeReceiptText ignores stale result when receiptID changes during OCR (Actor Reentrancy Guard)")
    func recognizeReceiptTextActorReentrancyReceiptIDGuard() async throws {
        let store = try SwiftDataReceiptStore.inMemory()

        let mockResult = ReceiptOCRResult(
            lines: [ReceiptOCRLine(text: "Stale Receipt", tokens: [], confidence: 0.9, boundingBox: .zero)],
            rawText: "Stale Receipt",
            averageConfidence: 0.9
        )
        let stub = StubReceiptOCRService(resultToReturn: mockResult, delay: .milliseconds(50))
        let vm = ReceiptEditorViewModel(store: store, ocrService: stub)

        vm.attachSampleReceipt(.taqueriaElPastor)
        let originalID = vm.receiptID

        // Start async recognition
        let task = Task {
            await vm.recognizeReceiptText()
        }

        // Wait until recognition task has actually started awaiting
        var yields = 0
        while !vm.isRecognizingText && yields < 50 {
            await Task.yield()
            yields += 1
        }
        #expect(vm.isRecognizingText)

        // Switch to a new receipt while OCR is awaiting in flight
        vm.startNewReceipt()
        #expect(vm.receiptID != originalID)

        await task.value

        // Stale result must NOT be applied to the newly active receipt
        #expect(vm.ocrRawText == nil)
        #expect(vm.lastOCRResult == nil)
        #expect(!vm.hasOCRText)
    }

    @Test("recognizeReceiptText ignores stale result when receiptImageData is replaced during OCR")
    func recognizeReceiptTextActorReentrancyImageDataGuard() async throws {
        let store = try SwiftDataReceiptStore.inMemory()

        let mockResult = ReceiptOCRResult(
            lines: [ReceiptOCRLine(text: "First Image Result", tokens: [], confidence: 0.9, boundingBox: .zero)],
            rawText: "First Image Result",
            averageConfidence: 0.9
        )
        let stub = StubReceiptOCRService(resultToReturn: mockResult, delay: .milliseconds(50))
        let vm = ReceiptEditorViewModel(store: store, ocrService: stub)

        vm.attachSampleReceipt(.taqueriaElPastor)

        let task = Task {
            await vm.recognizeReceiptText()
        }

        // Wait until recognition task has actually started awaiting
        var imageYields = 0
        while !vm.isRecognizingText && imageYields < 50 {
            await Task.yield()
            imageYields += 1
        }
        #expect(vm.isRecognizingText)

        // Replace image while OCR is actively in flight
        vm.attachSampleReceipt(.cafeCentral)

        await task.value

        // Discarded stale result
        #expect(vm.ocrRawText == nil)
        #expect(vm.lastOCRResult == nil)
    }

    @Test("removeReceiptImage clears ocrRawText and removes orphan record if image was sole content")
    func removeReceiptImageClearsOCRAndRemovesOrphanRecord() async throws {
        let store = try SwiftDataReceiptStore.inMemory()

        let mockResult = ReceiptOCRResult(
            lines: [ReceiptOCRLine(text: "Café Central", tokens: [], confidence: 0.9, boundingBox: .zero)],
            rawText: "Café Central",
            averageConfidence: 0.9
        )
        let stub = StubReceiptOCRService(resultToReturn: mockResult)
        let vm = ReceiptEditorViewModel(store: store, ocrService: stub)

        vm.attachSampleReceipt(.cafeCentral)
        await vm.recognizeReceiptText()

        #expect(vm.hasOCRText)
        #expect(try store.fetchAll().count == 1)

        // Removing image should clear OCR and delete orphan
        vm.removeReceiptImage()

        #expect(!vm.hasReceiptImage)
        #expect(vm.ocrRawText == nil)
        #expect(vm.lastOCRResult == nil)
        #expect(!vm.hasOCRText)
        #expect(try store.fetchAll().isEmpty)
    }

    @Test("applySuggestedTitleFromOCR populates title when empty and preserves existing title")
    func applySuggestedTitleFromOCRLifecycle() async throws {
        let mockResult = ReceiptOCRResult(
            lines: [
                ReceiptOCRLine(text: "TAQUERÍA EL PASTOR", tokens: [], confidence: 0.99, boundingBox: .zero),
                ReceiptOCRLine(text: "Av. Insurgentes Sur 1234", tokens: [], confidence: 0.95, boundingBox: .zero)
            ],
            rawText: "TAQUERÍA EL PASTOR\nAv. Insurgentes Sur 1234",
            averageConfidence: 0.97
        )
        let stub = StubReceiptOCRService(resultToReturn: mockResult)
        let vm = ReceiptEditorViewModel(ocrService: stub)

        vm.attachSampleReceipt(.taqueriaElPastor)
        await vm.recognizeReceiptText()

        #expect(vm.receiptTitle.isEmpty)
        vm.applySuggestedTitleFromOCR()
        #expect(vm.receiptTitle == "TAQUERÍA EL PASTOR")

        // Once title is set, applySuggestedTitleFromOCR must not overwrite it
        vm.receiptTitle = "Mi Cena Personalizada"
        vm.applySuggestedTitleFromOCR()
        #expect(vm.receiptTitle == "Mi Cena Personalizada")
    }

    @Test("applySuggestedTitleFromOCR falls back to ocrRawText first line when lastOCRResult is nil")
    func applySuggestedTitleFallsBackToRawText() {
        let vm = ReceiptEditorViewModel()

        let snapshot = ReceiptSnapshot(
            title: "",
            ocrRawText: "\n\nCafé Central Reforma\nTicket #00104\n"
        )
        vm.loadSnapshot(snapshot)

        #expect(vm.lastOCRResult == nil)
        #expect(vm.hasOCRText)

        vm.applySuggestedTitleFromOCR()
        #expect(vm.receiptTitle == "Café Central Reforma")
    }
}

// MARK: - Evaluation Fixtures Suite (Real Vision Neural Engine & Deterministic Reconstruction)

@Suite("Receipt OCR Synthetic Evaluation Fixtures", .serialized)
struct ReceiptOCREvaluationFixturesTests {

    @Test(
        "Evaluation Fixture: VisionReceiptOCRService recognizes merchant, reconstructed line items, and totals for all synthetic presets",
        .disabled(
            if: ProcessInfo.processInfo.environment["CI"] != nil || ProcessInfo.processInfo.environment["SIMCTL_CHILD_CI"] != nil,
            "Vision Neural Engine requires hardware acceleration unavailable in headless CI virtual machines"
        ),
        arguments: SampleReceiptPreset.allCases
    )
    func evaluatePresetRecognition(preset: SampleReceiptPreset) async throws {
        let service = VisionReceiptOCRService()
        let imageData = SampleReceiptImageGenerator.generateImageData(for: preset)

        let result = try await service.recognizeText(from: imageData)

        // 1. Overall Quality Checks
        #expect(!result.isEmpty)
        #expect(result.lines.count >= 8)
        #expect(result.averageConfidence > 0.6)

        // 2. Merchant Name Check in the top lines
        let topLinesText = result.lines.prefix(4).map(\.text).joined(separator: " ").uppercased()
        switch preset {
        case .taqueriaElPastor:
            #expect(topLinesText.contains("PASTOR") || topLinesText.contains("TAQUER"))
        case .pizzeriaNapoli:
            #expect(topLinesText.contains("NAPOLI") || topLinesText.contains("PIZZ"))
        case .cafeCentral:
            #expect(topLinesText.contains("CENTRAL") || topLinesText.contains("CAF"))
        }

        // 3. Crucial Geometric Reconstruction: Item name and price must be on the same reconstructed line
        for item in preset.items {
            let match = result.lines.contains { line in
                let upperText = line.text.uppercased()
                let cleanTotal = item.lineTotal.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
                let cleanUnit = item.unitPrice.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
                let hasPrice = upperText.contains(cleanTotal) || upperText.contains(cleanUnit) || upperText.contains(item.lineTotal)
                let nameWords = item.name.uppercased().split(separator: " ").filter { $0.count > 3 }
                let hasName = nameWords.contains { upperText.contains($0) }
                return hasPrice && hasName
            }
            #expect(match)
        }

        // 4. Total line check
        let totalLines = result.lines.filter { $0.text.uppercased().contains("TOTAL") }
        #expect(!totalLines.isEmpty)
    }

    @Test(
        "Deterministic geometric line reconstruction clusters item names and prices for all presets without Vision",
        arguments: SampleReceiptPreset.allCases
    )
    func evaluateDeterministicGeometricReconstructionForPresets(preset: SampleReceiptPreset) throws {
        var tokens: [ReceiptOCRToken] = []
        var currentY: CGFloat = 0.90

        // 1. Restaurant Header
        tokens.append(
            ReceiptOCRToken(
                text: preset.restaurantName,
                confidence: 0.99,
                boundingBox: CGRect(x: 0.20, y: currentY, width: 0.60, height: 0.03)
            )
        )
        currentY -= 0.06

        // 2. Preset Items (Scattered left and right tokens)
        for item in preset.items {
            let nameText = item.quantity > 1 ? "\(item.quantity)x \(item.name)" : item.name
            let nameToken = ReceiptOCRToken(
                text: nameText,
                confidence: 0.95,
                boundingBox: CGRect(x: 0.10, y: currentY, width: 0.50, height: 0.03)
            )
            let priceToken = ReceiptOCRToken(
                text: item.lineTotal,
                confidence: 0.95,
                boundingBox: CGRect(x: 0.70, y: currentY, width: 0.20, height: 0.03)
            )

            // Intentionally append price before name to verify horizontal sorting
            tokens.append(priceToken)
            tokens.append(nameToken)
            currentY -= 0.06
        }

        // 3. Subtotal
        tokens.append(
            ReceiptOCRToken(
                text: "SUBTOTAL",
                confidence: 0.92,
                boundingBox: CGRect(x: 0.10, y: currentY, width: 0.30, height: 0.03)
            )
        )
        tokens.append(
            ReceiptOCRToken(
                text: preset.subtotal,
                confidence: 0.92,
                boundingBox: CGRect(x: 0.70, y: currentY, width: 0.20, height: 0.03)
            )
        )
        currentY -= 0.06

        // 4. Tax
        tokens.append(
            ReceiptOCRToken(
                text: "IVA (16%)",
                confidence: 0.92,
                boundingBox: CGRect(x: 0.10, y: currentY, width: 0.30, height: 0.03)
            )
        )
        tokens.append(
            ReceiptOCRToken(
                text: preset.tax,
                confidence: 0.92,
                boundingBox: CGRect(x: 0.70, y: currentY, width: 0.20, height: 0.03)
            )
        )
        currentY -= 0.06

        // 5. Grand Total
        tokens.append(
            ReceiptOCRToken(
                text: "TOTAL",
                confidence: 0.98,
                boundingBox: CGRect(x: 0.10, y: currentY, width: 0.25, height: 0.03)
            )
        )
        tokens.append(
            ReceiptOCRToken(
                text: preset.grandTotal,
                confidence: 0.98,
                boundingBox: CGRect(x: 0.70, y: currentY, width: 0.20, height: 0.03)
            )
        )

        // Group scattered tokens
        let groupedLines = ReceiptOCRLineGrouper.group(tokens: tokens)

        #expect(!groupedLines.isEmpty)

        // Verify Restaurant Header is at the top
        let firstLine = try #require(groupedLines.first)
        #expect(firstLine.text.contains(preset.restaurantName))

        // Verify every preset item has its name and price on the same reconstructed line
        for item in preset.items {
            let match = groupedLines.contains { line in
                line.text.contains(item.name) && line.text.contains(item.lineTotal)
            }
            #expect(match, "Expected item '\(item.name)' and price '\(item.lineTotal)' on the same line")
        }

        // Verify Total line is clustered with "TOTAL" and grandTotal (excluding SUBTOTAL)
        let totalLine = groupedLines.first { line in
            line.text.hasPrefix("TOTAL") || (line.text.contains("TOTAL") && !line.text.contains("SUBTOTAL"))
        }
        let foundTotalLine = try #require(totalLine)
        #expect(foundTotalLine.text.contains(preset.grandTotal))
    }
}
