import Foundation

/// UI representation of the available line item splitting strategies.
nonisolated enum SplitModeKind: String, CaseIterable, Identifiable, Sendable {
    case wholeItem = "Individual"
    case equal = "Partes Iguales"
    case percentage = "Porcentaje"
    case portion = "Porciones"

    var id: String { rawValue }

    /// SF Symbol icon name representing the split mode in SwiftUI views.
    var systemImage: String {
        switch self {
        case .wholeItem:
            return "person.fill"
        case .equal:
            return "person.2.fill"
        case .percentage:
            return "percent"
        case .portion:
            return "chart.pie.fill"
        }
    }
}
