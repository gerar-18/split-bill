import Foundation
import CoreGraphics

/// Errors that can occur during optical character recognition (OCR) of receipt images.
public nonisolated enum ReceiptOCRError: Error, Equatable, Sendable {
    case invalidImageData
    case recognitionFailed(String)
}

/// An individual textual token or fragment recognized by the OCR engine.
///
/// Bounding box coordinates are normalized in `0...1` using Vision coordinate space:
/// origin `(0, 0)` is at the bottom-left corner of the image, with `x` extending right and `y` extending upward.
public nonisolated struct ReceiptOCRToken: Equatable, Sendable {
    public let text: String
    public let confidence: Float
    public let boundingBox: CGRect

    public init(text: String, confidence: Float, boundingBox: CGRect) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

/// A horizontal visual line formed by grouping one or more OCR tokens.
public nonisolated struct ReceiptOCRLine: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let text: String
    public let tokens: [ReceiptOCRToken]
    public let confidence: Float
    public let boundingBox: CGRect

    public init(
        id: UUID = UUID(),
        text: String,
        tokens: [ReceiptOCRToken],
        confidence: Float,
        boundingBox: CGRect
    ) {
        self.id = id
        self.text = text
        self.tokens = tokens
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

/// The aggregated result of performing OCR on a receipt image.
public nonisolated struct ReceiptOCRResult: Equatable, Sendable {
    public let lines: [ReceiptOCRLine]
    public let rawText: String
    public let averageConfidence: Float

    public var isEmpty: Bool { lines.isEmpty }

    public static let empty = ReceiptOCRResult(lines: [], rawText: "", averageConfidence: 0)

    public init(lines: [ReceiptOCRLine], rawText: String, averageConfidence: Float) {
        self.lines = lines
        self.rawText = rawText
        self.averageConfidence = averageConfidence
    }
}
