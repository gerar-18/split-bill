import CoreTransferable
import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Card Visual Themes

/// Visual styling theme for the rendered receipt share card.
enum ReceiptCardTheme: String, CaseIterable, Identifiable, Sendable {
    case classicLight = "Clásico"
    case midnightDark = "Nocturno"

    var id: String { rawValue }

    var backgroundColor: Color {
        switch self {
        case .classicLight:
            return Color(red: 0.98, green: 0.98, blue: 0.99)
        case .midnightDark:
            return Color(red: 0.08, green: 0.10, blue: 0.16)
        }
    }

    var cardBackground: Color {
        switch self {
        case .classicLight:
            return Color.white
        case .midnightDark:
            return Color(red: 0.12, green: 0.15, blue: 0.24)
        }
    }

    var primaryTextColor: Color {
        switch self {
        case .classicLight:
            return Color(red: 0.08, green: 0.10, blue: 0.15)
        case .midnightDark:
            return Color(red: 0.95, green: 0.96, blue: 0.98)
        }
    }

    var secondaryTextColor: Color {
        switch self {
        case .classicLight:
            return Color(red: 0.40, green: 0.45, blue: 0.54)
        case .midnightDark:
            return Color(red: 0.65, green: 0.70, blue: 0.80)
        }
    }

    var dividerColor: Color {
        switch self {
        case .classicLight:
            return Color.black.opacity(0.08)
        case .midnightDark:
            return Color.white.opacity(0.12)
        }
    }

    var badgeBackground: Color {
        switch self {
        case .classicLight:
            return Color(red: 0.92, green: 0.95, blue: 0.98)
        case .midnightDark:
            return Color(red: 0.16, green: 0.21, blue: 0.32)
        }
    }
}

// MARK: - Receipt Share Card Data Models

/// An immutable, UI-ready snapshot of receipt totals and per-person allocations
/// formatted for visual infographic rendering.
struct ReceiptShareCardData: Sendable, Equatable {
    let title: String
    let dateText: String
    let currency: Currency
    let itemsSubtotal: Money
    let tax: Money
    let tip: Money
    let grandTotal: Money
    let participantRows: [ParticipantShareRow]

    var hasTax: Bool { tax.amountInMinorUnits > 0 }
    var hasTip: Bool { tip.amountInMinorUnits > 0 }

    struct ParticipantShareRow: Identifiable, Sendable, Equatable {
        let id: UUID
        let name: String
        let total: Money
        let itemsSubtotal: Money
        let tax: Money
        let tip: Money
        let assignedItems: [AssignedItemShare]
    }

    struct AssignedItemShare: Identifiable, Sendable, Equatable {
        let id: UUID
        let name: String
        let share: Money
        let quantity: Int
    }
}

// MARK: - CoreTransferable Image Container

/// Transferable representation allowing `ShareLink` to export native PNG files
/// with a title and preview thumbnail.
struct ShareableReceiptImage: Transferable {
    let pngData: Data
    let title: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            item.pngData
        }
        .suggestedFileName { item in
            let sanitized = item.title
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: " ", with: "_")
            let name = sanitized.isEmpty ? "SplitBill_Resumen" : "SplitBill_\(sanitized)"
            return "\(name).png"
        }
    }
}
