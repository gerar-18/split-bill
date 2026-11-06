import Testing
import Foundation
import CoreGraphics
@testable import SplitBill

@Suite("Receipt OCR & Geometric Grouper Tests")
struct ReceiptOCRTests {

    // MARK: - Geometric Grouper Tests

    @Test("ReceiptOCRLineGrouper returns empty lines for empty token input")
    func lineGrouperEmptyInput() {
        let result = ReceiptOCRLineGrouper.group(tokens: [])
        #expect(result.isEmpty)
    }

    @Test("ReceiptOCRLineGrouper clusters horizontally aligned tokens and orders them left-to-right")
    func lineGrouperHorizontalClustering() {
        // Two tokens on the same horizontal row (midY ~ 0.80)
        let tokenPrice = ReceiptOCRToken(
            text: "$170.00",
            confidence: 0.95,
            boundingBox: CGRect(x: 0.70, y: 0.79, width: 0.20, height: 0.03)
        )
        let tokenItem = ReceiptOCRToken(
            text: "2x Tacos al Pastor",
            confidence: 0.92,
            boundingBox: CGRect(x: 0.05, y: 0.81, width: 0.45, height: 0.03)
        )

        // Pass them in reverse horizontal order to verify sorting
        let lines = ReceiptOCRLineGrouper.group(tokens: [tokenPrice, tokenItem])

        #expect(lines.count == 1)
        if let firstLine = lines.first {
            #expect(firstLine.text == "2x Tacos al Pastor $170.00")
            #expect(firstLine.tokens.count == 2)
            if firstLine.tokens.count == 2 {
                #expect(firstLine.tokens[0].text == "2x Tacos al Pastor")
                #expect(firstLine.tokens[1].text == "$170.00")
            }
        }
    }

    @Test("ReceiptOCRLineGrouper orders lines top-to-bottom according to Vision's bottom-left origin")
    func lineGrouperVerticalOrdering() {
        let bottomLine = ReceiptOCRToken(
            text: "TOTAL $498.80",
            confidence: 0.98,
            boundingBox: CGRect(x: 0.05, y: 0.20, width: 0.80, height: 0.04)
        )
        let topLine = ReceiptOCRToken(
            text: "TAQUERÍA EL PASTOR",
            confidence: 0.99,
            boundingBox: CGRect(x: 0.10, y: 0.90, width: 0.80, height: 0.04)
        )
        let midLine = ReceiptOCRToken(
            text: "Ticket #00428",
            confidence: 0.90,
            boundingBox: CGRect(x: 0.05, y: 0.60, width: 0.40, height: 0.03)
        )

        let lines = ReceiptOCRLineGrouper.group(tokens: [bottomLine, topLine, midLine])

        #expect(lines.count == 3)
        #expect(lines[0].text == "TAQUERÍA EL PASTOR")
        #expect(lines[1].text == "Ticket #00428")
        #expect(lines[2].text == "TOTAL $498.80")
    }

    // MARK: - Models Tests

    @Test("ReceiptOCRResult empty constant properties")
    func emptyResultVerification() {
        let empty = ReceiptOCRResult.empty
        #expect(empty.isEmpty)
        #expect(empty.lines.isEmpty)
        #expect(empty.rawText.isEmpty)
        #expect(empty.averageConfidence == 0)
    }

    @Test("ReceiptOCRError equality check")
    func errorEquality() {
        #expect(ReceiptOCRError.invalidImageData == ReceiptOCRError.invalidImageData)
        #expect(ReceiptOCRError.recognitionFailed("err") == ReceiptOCRError.recognitionFailed("err"))
        #expect(ReceiptOCRError.recognitionFailed("a") != ReceiptOCRError.recognitionFailed("b"))
        #expect(ReceiptOCRError.invalidImageData != ReceiptOCRError.recognitionFailed("other"))
    }

    // MARK: - Vision Service End-to-End Tests

    @Test("VisionReceiptOCRService throws invalidImageData on corrupt bytes")
    func visionServiceCorruptBytes() async {
        let service = VisionReceiptOCRService()
        let corruptData = Data([0xDE, 0xAD, 0xBE, 0xEF])

        await #expect(throws: ReceiptOCRError.invalidImageData) {
            _ = try await service.recognizeText(from: corruptData)
        }
    }
}
