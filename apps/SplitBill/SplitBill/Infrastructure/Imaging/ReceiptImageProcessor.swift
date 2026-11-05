import Foundation
import UIKit

/// Processes receipt images prior to storage or OCR.
///
/// Responsibilities:
/// 1. Normalizes EXIF orientation to `.up` via `UIGraphicsImageRenderer`.
/// 2. Proportionally scales down images whose maximum dimension exceeds `maxDimension` (default: 2048 pt),
///    without upscaling images that are already smaller.
/// 3. Compresses the resulting bitmap to JPEG with configurable quality (default: 0.82).
public nonisolated enum ReceiptImageProcessor: Sendable {

    /// Default maximum dimension (in points/pixels) for processed receipt images.
    public static let defaultMaxDimension: CGFloat = 2048

    /// Default JPEG compression quality (0.0 to 1.0).
    public static let defaultCompressionQuality: CGFloat = 0.82

    /// Processes a `UIImage` by normalizing orientation, downscaling if necessary, and compressing to JPEG.
    ///
    /// - Parameters:
    ///   - image: The source `UIImage`.
    ///   - maxDimension: Maximum allowed width or height in points/pixels.
    ///   - compressionQuality: JPEG compression quality (0.0 to 1.0).
    /// - Returns: Re-encoded JPEG data, or `nil` if dimensions are invalid or processing fails.
    public static func process(
        _ image: UIImage,
        maxDimension: CGFloat = defaultMaxDimension,
        compressionQuality: CGFloat = defaultCompressionQuality
    ) -> Data? {
        let originalSize = image.size
        guard originalSize.width >= 1, originalSize.height >= 1 else {
            return nil
        }
        guard maxDimension > 0, compressionQuality >= 0 && compressionQuality <= 1 else {
            return nil
        }

        let longestSide = max(originalSize.width, originalSize.height)
        let targetSize: CGSize
        if longestSide > maxDimension {
            let scaleFactor = maxDimension / longestSide
            targetSize = CGSize(
                width: max(1, (originalSize.width * scaleFactor).rounded()),
                height: max(1, (originalSize.height * scaleFactor).rounded())
            )
        } else {
            targetSize = CGSize(
                width: max(1, originalSize.width.rounded()),
                height: max(1, originalSize.height.rounded())
            )
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let normalizedImage = renderer.image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: targetSize))
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return normalizedImage.jpegData(compressionQuality: compressionQuality)
    }

    /// Decodes raw image data, normalizes orientation and dimensions, and compresses to JPEG.
    ///
    /// - Parameters:
    ///   - data: Raw image data (e.g. JPEG, PNG, HEIC).
    ///   - maxDimension: Maximum allowed width or height.
    ///   - compressionQuality: JPEG compression quality.
    /// - Returns: Re-encoded JPEG data, or `nil` if data is corrupt or invalid.
    public static func process(
        data: Data,
        maxDimension: CGFloat = defaultMaxDimension,
        compressionQuality: CGFloat = defaultCompressionQuality
    ) -> Data? {
        guard let image = UIImage(data: data) else {
            return nil
        }
        return process(image, maxDimension: maxDimension, compressionQuality: compressionQuality)
    }
}
