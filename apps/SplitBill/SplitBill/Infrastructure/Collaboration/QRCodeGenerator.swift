import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Pure CoreImage QR code generator with zero external dependencies.
nonisolated enum QRCodeGenerator {

    /// Generates an interpolated-free sharp QR `UIImage` for the provided string.
    static func generate(from content: String, dimension: CGFloat = 240) -> UIImage? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
            return nil
        }

        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else {
            return nil
        }

        let extent = outputImage.extent.integral
        guard extent.width > 0, extent.height > 0 else {
            return nil
        }

        let scale = max(1, (dimension / extent.width).rounded(.down))
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
