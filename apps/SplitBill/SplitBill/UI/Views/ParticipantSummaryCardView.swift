import SwiftUI

/// Card view displaying an individual participant's calculated share: total owed,
/// breakdown (items subtotal, proportional tax, proportional tip), and an itemized
/// list of assigned items with their exact allocated money share.
struct ParticipantSummaryCardView: View {

    // MARK: - Properties

    let participant: Participant
    let summary: ParticipantSplitSummary
    let items: [ReceiptItem]
    let itemAllocations: [ReceiptItem.ID: [Participant.ID: Money]]

    // MARK: - Computed Properties

    /// Filtered list of receipt items where this participant has an allocated share > 0.
    private var assignedItems: [(item: ReceiptItem, share: Money)] {
        items.compactMap { item in
            guard let share = itemAllocations[item.id]?[participant.id],
                  share.amountInMinorUnits > 0 else {
                return nil
            }
            return (item, share)
        }
    }

    private var accessibilityVoiceOverLabel: String {
        let totalStr = MoneyFormatter.string(from: summary.total)
        let itemsStr = MoneyFormatter.string(from: summary.itemsSubtotal)
        let taxStr = MoneyFormatter.string(from: summary.taxAllocated)
        let tipStr = MoneyFormatter.string(from: summary.tipAllocated)

        var text = "\(participant.name), total a pagar: \(totalStr). Desglose: consumo \(itemsStr), impuesto \(taxStr), propina \(tipStr)."

        if !assignedItems.isEmpty {
            let itemsListStr = assignedItems.map { pair in
                "\(pair.item.name): \(MoneyFormatter.string(from: pair.share))"
            }.joined(separator: ", ")
            text += " Artículos asignados: \(itemsListStr)."
        }
        return text
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Avatar, Name, and Total Owed
            headerRow

            // Breakdown Sub-row: Consumo, Impuesto, Propina
            breakdownRow

            // Itemized List of Assigned Items
            if !assignedItems.isEmpty {
                Divider()
                assignedItemsList
            }
        }
        .padding(14)
        .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityVoiceOverLabel)
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title2)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text(participant.name)
                .font(.headline)
                .lineLimit(2)
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            Text(MoneyFormatter.string(from: summary.total))
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }

    private var breakdownRow: some View {
        HStack(spacing: 8) {
            breakdownMetric(label: "Consumo", amount: summary.itemsSubtotal)
            breakdownMetric(label: "Impuesto", amount: summary.taxAllocated)
            breakdownMetric(label: "Propina", amount: summary.tipAllocated)
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private func breakdownMetric(label: String, amount: Money) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(MoneyFormatter.string(from: amount, includeCurrencyCode: false))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var assignedItemsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Artículos Asignados")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            ForEach(assignedItems, id: \.item.id) { pair in
                HStack {
                    Text(pair.item.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    Text(MoneyFormatter.string(from: pair.share, includeCurrencyCode: false))
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let p = try! Participant(name: "Ana García")
    let summary = ParticipantSplitSummary(
        participantID: p.id,
        itemsSubtotal: Money(amountInMinorUnits: 25000, currency: .mxn),
        taxAllocated: Money(amountInMinorUnits: 4000, currency: .mxn),
        tipAllocated: Money(amountInMinorUnits: 2500, currency: .mxn),
        total: Money(amountInMinorUnits: 31500, currency: .mxn)
    )
    let item1 = try! ReceiptItem(
        name: "Tacos al Pastor",
        unitPrice: Money(amountInMinorUnits: 15000, currency: .mxn),
        quantity: 1,
        splitMode: .wholeItem(p.id)
    )
    let item2 = try! ReceiptItem(
        name: "Guacamole al Centro",
        unitPrice: Money(amountInMinorUnits: 20000, currency: .mxn),
        quantity: 1,
        splitMode: .equal([p.id])
    )
    let allocations: [ReceiptItem.ID: [Participant.ID: Money]] = [
        item1.id: [p.id: Money(amountInMinorUnits: 15000, currency: .mxn)],
        item2.id: [p.id: Money(amountInMinorUnits: 10000, currency: .mxn)]
    ]

    return VStack {
        ParticipantSummaryCardView(
            participant: p,
            summary: summary,
            items: [item1, item2],
            itemAllocations: allocations
        )
    }
    .padding()
}
