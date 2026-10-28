import SwiftUI

/// Row view displaying a single `ReceiptItem`'s name, quantity, unit price, split badge, and total.
struct ReceiptItemRowView: View {

    // MARK: - Properties

    let item: ReceiptItem
    let participants: [Participant]

    // MARK: - Body

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Text(subtitleText)
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)

                    splitModeBadge
                }
            }

            Spacer(minLength: 8)

            Text(MoneyFormatter.string(from: item.lineTotal, includeCurrencyCode: false))
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: - Subviews

    private var splitModeBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: splitModeIcon)
                .imageScale(.small)
                .accessibilityHidden(true)

            Text(splitModeLabel)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.quaternary, in: .capsule)
        .foregroundStyle(.secondary)
    }

    // MARK: - Computed Properties

    private var subtitleText: String {
        let unitPriceString = MoneyFormatter.string(from: item.unitPrice, includeCurrencyCode: false)
        if item.quantity > 1 {
            return "\(item.quantity) × \(unitPriceString)"
        } else {
            return unitPriceString
        }
    }

    private var splitModeIcon: String {
        switch item.splitMode {
        case .wholeItem:
            return SplitModeKind.wholeItem.systemImage
        case .equal:
            return SplitModeKind.equal.systemImage
        case .percentage:
            return SplitModeKind.percentage.systemImage
        case .portion:
            return SplitModeKind.portion.systemImage
        }
    }

    private var splitModeLabel: String {
        switch item.splitMode {
        case .wholeItem(let id):
            return "Para \(participantName(for: id))"
        case .equal(let ids):
            return "Partes iguales (\(ids.count))"
        case .percentage(let pcts):
            return "Porcentaje (\(pcts.count))"
        case .portion(let ports):
            return "Porciones (\(ports.count))"
        }
    }

    private var accessibilitySummary: String {
        let totalStr = MoneyFormatter.string(from: item.lineTotal, includeCurrencyCode: true)
        return "\(item.name), \(subtitleText), Total \(totalStr), \(splitModeLabel)"
    }

    // MARK: - Helpers

    private func participantName(for id: Participant.ID) -> String {
        participants.first(where: { $0.id == id })?.name ?? "Desconocido"
    }
}

// MARK: - Previews

#Preview("All Split Modes") {
    let p1 = try? Participant(name: "Ana")
    let p2 = try? Participant(name: "Carlos")
    let p3 = try? Participant(name: "Sofía")
    let participants = [p1, p2, p3].compactMap { $0 }

    let itemWhole = try? ReceiptItem(
        name: "Cerveza Artesanal",
        unitPrice: Money(amountInMinorUnits: 8500, currency: .mxn),
        quantity: 2,
        splitMode: .wholeItem(participants[0].id)
    )

    let itemEqual = try? ReceiptItem(
        name: "Guacamole al Centro",
        unitPrice: Money(amountInMinorUnits: 14000, currency: .mxn),
        quantity: 1,
        splitMode: .equal(Set(participants.map(\.id)))
    )

    let itemPercentage = try? ReceiptItem(
        name: "Botella de Vino",
        unitPrice: Money(amountInMinorUnits: 65000, currency: .mxn),
        quantity: 1,
        splitMode: .percentage([participants[0].id: 50, participants[1].id: 50])
    )

    let itemPortion = try? ReceiptItem(
        name: "Parrillada Mixta",
        unitPrice: Money(amountInMinorUnits: 48000, currency: .mxn),
        quantity: 1,
        splitMode: .portion([participants[0].id: 2, participants[1].id: 1, participants[2].id: 1])
    )

    return List {
        if let itemWhole {
            ReceiptItemRowView(item: itemWhole, participants: participants)
        }
        if let itemEqual {
            ReceiptItemRowView(item: itemEqual, participants: participants)
        }
        if let itemPercentage {
            ReceiptItemRowView(item: itemPercentage, participants: participants)
        }
        if let itemPortion {
            ReceiptItemRowView(item: itemPortion, participants: participants)
        }
    }
}
