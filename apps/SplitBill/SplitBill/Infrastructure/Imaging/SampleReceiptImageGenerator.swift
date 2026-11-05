import Foundation
import UIKit

/// Preset catalog of realistic restaurant receipts used for testing, manual mocks, and OCR validation.
public nonisolated enum SampleReceiptPreset: String, CaseIterable, Identifiable, Sendable {
    case taqueriaElPastor = "Taquería El Pastor"
    case pizzeriaNapoli = "Pizzería Napoli"
    case cafeCentral = "Café Central"

    public var id: String { rawValue }
    public var displayName: String { rawValue }

    public nonisolated struct LineItem: Sendable {
        public let name: String
        public let quantity: Int
        public let unitPrice: String
        public let lineTotal: String

        public init(name: String, quantity: Int, unitPrice: String, lineTotal: String) {
            self.name = name
            self.quantity = quantity
            self.unitPrice = unitPrice
            self.lineTotal = lineTotal
        }
    }

    public var restaurantName: String { rawValue }

    public var address: String {
        switch self {
        case .taqueriaElPastor:
            return "Av. Insurgentes Sur 1234, CDMX"
        case .pizzeriaNapoli:
            return "Calle Orizaba 45, Roma Norte, CDMX"
        case .cafeCentral:
            return "Paseo de la Reforma 222, CDMX"
        }
    }

    public var dateString: String {
        switch self {
        case .taqueriaElPastor:
            return "2026-11-05 14:32"
        case .pizzeriaNapoli:
            return "2026-11-05 20:15"
        case .cafeCentral:
            return "2026-11-05 09:45"
        }
    }

    public var ticketNumber: String {
        switch self {
        case .taqueriaElPastor:
            return "Ticket #00428"
        case .pizzeriaNapoli:
            return "Ticket #01892"
        case .cafeCentral:
            return "Ticket #00104"
        }
    }

    public var items: [LineItem] {
        switch self {
        case .taqueriaElPastor:
            return [
                LineItem(name: "Tacos al Pastor", quantity: 2, unitPrice: "$85.00", lineTotal: "$170.00"),
                LineItem(name: "Gringa de Pastor", quantity: 1, unitPrice: "$95.00", lineTotal: "$95.00"),
                LineItem(name: "Guacamole Especial", quantity: 1, unitPrice: "$75.00", lineTotal: "$75.00"),
                LineItem(name: "Agua de Horchata 1L", quantity: 2, unitPrice: "$45.00", lineTotal: "$90.00")
            ]
        case .pizzeriaNapoli:
            return [
                LineItem(name: "Pizza Margherita", quantity: 1, unitPrice: "$220.00", lineTotal: "$220.00"),
                LineItem(name: "Pizza Quattro Formaggi", quantity: 1, unitPrice: "$280.00", lineTotal: "$280.00"),
                LineItem(name: "Ensalada Caprese", quantity: 1, unitPrice: "$160.00", lineTotal: "$160.00"),
                LineItem(name: "Copa Vino Tinto", quantity: 2, unitPrice: "$130.00", lineTotal: "$260.00")
            ]
        case .cafeCentral:
            return [
                LineItem(name: "Café Americano", quantity: 2, unitPrice: "$50.00", lineTotal: "$100.00"),
                LineItem(name: "Croissant Mantequilla", quantity: 1, unitPrice: "$55.00", lineTotal: "$55.00"),
                LineItem(name: "Huevos Benedictinos", quantity: 1, unitPrice: "$165.00", lineTotal: "$165.00"),
                LineItem(name: "Jugo Verde Natural", quantity: 1, unitPrice: "$60.00", lineTotal: "$60.00")
            ]
        }
    }

    public var subtotal: String {
        switch self {
        case .taqueriaElPastor: return "$430.00"
        case .pizzeriaNapoli: return "$920.00"
        case .cafeCentral: return "$380.00"
        }
    }

    public var tax: String {
        switch self {
        case .taqueriaElPastor: return "$68.80"
        case .pizzeriaNapoli: return "$147.20"
        case .cafeCentral: return "$60.80"
        }
    }

    public var suggestedTip: String {
        switch self {
        case .taqueriaElPastor: return "$43.00 (10%)"
        case .pizzeriaNapoli: return "$138.00 (15%)"
        case .cafeCentral: return "$38.00 (10%)"
        }
    }

    public var grandTotal: String {
        switch self {
        case .taqueriaElPastor: return "$498.80"
        case .pizzeriaNapoli: return "$1,067.20"
        case .cafeCentral: return "$440.80"
        }
    }
}

/// Renders realistic synthetic receipt ticket bitmaps on a light paper background.
public nonisolated enum SampleReceiptImageGenerator: Sendable {

    /// Fixed layout width for generated receipts.
    public static let receiptWidth: CGFloat = 400.0

    /// Generates a rendered `UIImage` receipt ticket for the specified preset.
    public static func generateImage(for preset: SampleReceiptPreset) -> UIImage {
        let width: CGFloat = receiptWidth
        let margin: CGFloat = 24.0
        let contentWidth = width - (margin * 2)

        let titleFont = UIFont.monospacedSystemFont(ofSize: 18, weight: .bold)
        let subheaderFont = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let bodyFont = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let totalFont = UIFont.monospacedSystemFont(ofSize: 16, weight: .bold)
        let smallFont = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)

        // Calculate total vertical height
        var totalHeight: CGFloat = 0
        totalHeight += 28 // Top margin
        totalHeight += 24 // Restaurant title
        totalHeight += 16 // Address
        totalHeight += 16 // Ticket & date
        totalHeight += 20 // Divider
        totalHeight += 18 // Table header
        totalHeight += 12 // Spacing

        for item in preset.items {
            totalHeight += 20 // Item line
            if item.quantity > 1 {
                totalHeight += 14 // Quantity detail
            }
            totalHeight += 4 // Spacing
        }

        totalHeight += 16 // Divider
        totalHeight += 20 // Subtotal
        totalHeight += 20 // Tax
        totalHeight += 16 // Divider
        totalHeight += 26 // Grand Total
        totalHeight += 20 // Suggested tip
        totalHeight += 20 // Divider
        totalHeight += 18 // Footer message
        totalHeight += 28 // Bottom margin

        let size = CGSize(width: width, height: totalHeight)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2.0 // High-DPI crisp rendering
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            // Clean off-white receipt paper background
            let paperColor = UIColor(red: 0.98, green: 0.98, blue: 0.96, alpha: 1.0)
            paperColor.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            // Subtle perimeter border
            let borderColor = UIColor(red: 0.88, green: 0.88, blue: 0.86, alpha: 1.0)
            borderColor.setStroke()
            let borderRect = CGRect(x: 8, y: 8, width: width - 16, height: totalHeight - 16)
            ctx.stroke(borderRect)

            var y: CGFloat = 28

            func drawCentered(_ text: String, font: UIFont, color: UIColor = .black) {
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: paragraph
                ]
                let rect = CGRect(x: margin, y: y, width: contentWidth, height: font.lineHeight + 4)
                (text as NSString).draw(in: rect, withAttributes: attrs)
                y += font.lineHeight + 4
            }

            func drawDivider() {
                y += 4
                let dividerColor = UIColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1.0)
                dividerColor.setStroke()
                let path = UIBezierPath()
                let pattern: [CGFloat] = [4, 3]
                path.setLineDash(pattern, count: 2, phase: 0)
                path.lineWidth = 1.0
                path.move(to: CGPoint(x: margin, y: y))
                path.addLine(to: CGPoint(x: margin + contentWidth, y: y))
                path.stroke()
                y += 8
            }

            func drawRow(left: String, right: String, font: UIFont, color: UIColor = .black) {
                let rightAttrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color
                ]
                let rightSize = (right as NSString).size(withAttributes: rightAttrs)
                let rightRect = CGRect(
                    x: margin + contentWidth - rightSize.width,
                    y: y,
                    width: rightSize.width,
                    height: font.lineHeight + 2
                )
                (right as NSString).draw(in: rightRect, withAttributes: rightAttrs)

                let leftAttrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color
                ]
                let leftRect = CGRect(
                    x: margin,
                    y: y,
                    width: contentWidth - rightSize.width - 8,
                    height: font.lineHeight + 2
                )
                (left as NSString).draw(in: leftRect, withAttributes: leftAttrs)
                y += font.lineHeight + 4
            }

            // Header
            drawCentered(preset.restaurantName, font: titleFont)
            drawCentered(preset.address, font: subheaderFont, color: .darkGray)
            let meta = "\(preset.ticketNumber)  •  \(preset.dateString)"
            drawCentered(meta, font: subheaderFont, color: .darkGray)

            drawDivider()

            // Columns
            drawRow(left: "DESCRIPCIÓN", right: "IMPORTE", font: smallFont, color: .gray)

            // Items
            for item in preset.items {
                let namePrefix = item.quantity > 1 ? "\(item.quantity)x \(item.name)" : item.name
                drawRow(left: namePrefix, right: item.lineTotal, font: bodyFont)
                if item.quantity > 1 {
                    let detail = "   (\(item.quantity) @ \(item.unitPrice))"
                    let detailAttrs: [NSAttributedString.Key: Any] = [
                        .font: smallFont,
                        .foregroundColor: UIColor.gray
                    ]
                    let detailRect = CGRect(x: margin, y: y - 2, width: contentWidth, height: smallFont.lineHeight + 2)
                    (detail as NSString).draw(in: detailRect, withAttributes: detailAttrs)
                    y += smallFont.lineHeight + 2
                }
            }

            drawDivider()

            // Subtotals
            drawRow(left: "SUBTOTAL", right: preset.subtotal, font: bodyFont)
            drawRow(left: "IVA (16%)", right: preset.tax, font: bodyFont)

            drawDivider()

            // Total
            drawRow(left: "TOTAL", right: preset.grandTotal, font: totalFont, color: .black)

            // Suggested Tip
            drawRow(left: "PROPINA SUGERIDA", right: preset.suggestedTip, font: smallFont, color: .darkGray)

            drawDivider()

            // Footer
            drawCentered("¡GRACIAS POR SU PREFERENCIA!", font: subheaderFont, color: .darkGray)
        }
    }

    /// Generates compressed JPEG data for the specified preset.
    public static func generateImageData(for preset: SampleReceiptPreset) -> Data {
        let image = generateImage(for: preset)
        if let processed = ReceiptImageProcessor.process(image) {
            return processed
        }
        return image.jpegData(compressionQuality: ReceiptImageProcessor.defaultCompressionQuality) ?? Data()
    }
}
