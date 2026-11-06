import Foundation
import UIKit
import Vision

/// Service protocol for asynchronous Optical Character Recognition (OCR) on receipt images.
public nonisolated protocol ReceiptOCRService: Sendable {
    func recognizeText(from imageData: Data) async throws(ReceiptOCRError) -> ReceiptOCRResult
}

/// Pure geometric row-clustering algorithm that groups scattered OCR tokens into coherent visual lines.
public nonisolated enum ReceiptOCRLineGrouper: Sendable {

    private struct LineCluster {
        var tokens: [ReceiptOCRToken]

        var averageMidY: CGFloat {
            guard !tokens.isEmpty else { return 0 }
            let sum = tokens.reduce(CGFloat.zero) { $0 + $1.boundingBox.midY }
            return sum / CGFloat(tokens.count)
        }

        var averageHeight: CGFloat {
            guard !tokens.isEmpty else { return 0 }
            let sum = tokens.reduce(CGFloat.zero) { $0 + $1.boundingBox.height }
            return sum / CGFloat(tokens.count)
        }

        func distance(to token: ReceiptOCRToken) -> CGFloat {
            abs(token.boundingBox.midY - averageMidY)
        }

        func canInclude(token: ReceiptOCRToken) -> Bool {
            let threshold = max(token.boundingBox.height, averageHeight) * 0.85
            if distance(to: token) <= threshold {
                return true
            }

            // Fallback: check vertical interval overlap
            let clusterMinY = tokens.map(\.boundingBox.minY).min() ?? 0
            let clusterMaxY = tokens.map(\.boundingBox.maxY).max() ?? 0
            let overlapMin = max(token.boundingBox.minY, clusterMinY)
            let overlapMax = min(token.boundingBox.maxY, clusterMaxY)
            if overlapMax > overlapMin {
                let overlap = overlapMax - overlapMin
                let minH = min(token.boundingBox.height, averageHeight)
                if minH > 0 && (overlap / minH) >= 0.3 {
                    return true
                }
            }
            return false
        }
    }

    /// Groups a collection of OCR tokens into visual lines ordered from top to bottom.
    ///
    /// - Parameter tokens: Recognized tokens with normalized bounding boxes (Vision bottom-left origin).
    /// - Returns: Coalesced visual lines ordered descending by `midY` (top to bottom of receipt).
    public static func group(tokens: [ReceiptOCRToken]) -> [ReceiptOCRLine] {
        guard !tokens.isEmpty else { return [] }

        // Vision origin is bottom-left (y goes 0 -> 1 upwards).
        // Higher midY means closer to the top of the receipt ticket.
        let sortedTokens = tokens.sorted { $0.boundingBox.midY > $1.boundingBox.midY }

        var clusters: [LineCluster] = []

        for token in sortedTokens {
            var bestClusterIndex: Int?
            var smallestDistance: CGFloat = .greatestFiniteMagnitude

            for (index, cluster) in clusters.enumerated() {
                if cluster.canInclude(token: token) {
                    let dist = cluster.distance(to: token)
                    if dist < smallestDistance {
                        smallestDistance = dist
                        bestClusterIndex = index
                    }
                }
            }

            if let bestClusterIndex {
                clusters[bestClusterIndex].tokens.append(token)
            } else {
                clusters.append(LineCluster(tokens: [token]))
            }
        }

        var resultLines: [ReceiptOCRLine] = []

        for cluster in clusters {
            // Sort tokens horizontally from left to right (minX ascending)
            let horizontalTokens = cluster.tokens.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
            guard let firstToken = horizontalTokens.first else { continue }

            let lineText = horizontalTokens.map(\.text).joined(separator: " ")
            let unionBox = horizontalTokens.reduce(firstToken.boundingBox) { $0.union($1.boundingBox) }
            let confidenceSum = horizontalTokens.reduce(Float(0)) { $0 + $1.confidence }
            let avgConfidence = confidenceSum / Float(horizontalTokens.count)

            let line = ReceiptOCRLine(
                text: lineText,
                tokens: horizontalTokens,
                confidence: avgConfidence,
                boundingBox: unionBox
            )
            resultLines.append(line)
        }

        // Sort lines from top of receipt to bottom (midY descending)
        return resultLines.sorted { $0.boundingBox.midY > $1.boundingBox.midY }
    }
}

/// Vision-based implementation of `ReceiptOCRService` executing on Apple's Neural Engine.
public nonisolated final class VisionReceiptOCRService: ReceiptOCRService {

    public init() {}

    public func recognizeText(from imageData: Data) async throws(ReceiptOCRError) -> ReceiptOCRResult {
        guard let uiImage = UIImage(data: imageData) else {
            throw ReceiptOCRError.invalidImageData
        }

        // Avoid re-encoding to JPEG if a direct CGImage is already available in memory
        let cgImage: CGImage
        let orientation: CGImagePropertyOrientation
        if let directCG = uiImage.cgImage {
            cgImage = directCG
            orientation = CGImagePropertyOrientation(uiImage.imageOrientation)
        } else if let processedData = ReceiptImageProcessor.process(data: imageData),
                  let processedImage = UIImage(data: processedData),
                  let fallbackCG = processedImage.cgImage {
            cgImage = fallbackCG
            orientation = CGImagePropertyOrientation(processedImage.imageOrientation)
        } else {
            throw ReceiptOCRError.invalidImageData
        }

        do {
            // Offload CPU/Vision-intensive task to a dedicated GCD queue via checked continuation
            // to avoid starving Swift Concurrency's cooperative thread pool.
            let tokens: [ReceiptOCRToken] = try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    request.usesLanguageCorrection = true
                    request.recognitionLanguages = ["es-MX", "es-ES", "en-US"]

                    let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
                    do {
                        try handler.perform([request])
                    } catch {
                        continuation.resume(throwing: ReceiptOCRError.recognitionFailed(error.localizedDescription))
                        return
                    }

                    guard let observations = request.results else {
                        continuation.resume(returning: [])
                        return
                    }

                    var extractedTokens: [ReceiptOCRToken] = []
                    for observation in observations {
                        guard let topCandidate = observation.topCandidates(1).first else {
                            continue
                        }
                        let cleanedText = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !cleanedText.isEmpty else { continue }

                        extractedTokens.append(
                            ReceiptOCRToken(
                                text: cleanedText,
                                confidence: topCandidate.confidence,
                                boundingBox: observation.boundingBox
                            )
                        )
                    }
                    continuation.resume(returning: extractedTokens)
                }
            }

            if Task.isCancelled {
                return .empty
            }

            let lines = ReceiptOCRLineGrouper.group(tokens: tokens)
            if lines.isEmpty {
                return .empty
            }

            let rawText = lines.map(\.text).joined(separator: "\n")
            let totalConfidence = lines.reduce(Float(0)) { $0 + $1.confidence }
            let averageConfidence = totalConfidence / Float(lines.count)

            return ReceiptOCRResult(
                lines: lines,
                rawText: rawText,
                averageConfidence: averageConfidence
            )
        } catch let error as ReceiptOCRError {
            throw error
        } catch {
            throw ReceiptOCRError.recognitionFailed(error.localizedDescription)
        }
    }
}

// MARK: - CGImagePropertyOrientation Helper

private extension CGImagePropertyOrientation {
    nonisolated init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
