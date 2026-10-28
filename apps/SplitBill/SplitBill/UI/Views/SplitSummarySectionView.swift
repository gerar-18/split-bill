import SwiftUI

/// Section view displaying the complete per-person split summary cards,
/// mathematical reconciliation badge, and native share link.
struct SplitSummarySectionView: View {

    // MARK: - Properties

    let viewModel: ReceiptEditorViewModel

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            headerRow

            // Content based on split availability
            if let result = viewModel.splitResult, !viewModel.items.isEmpty {
                reconciliationBadge(result: result)

                VStack(spacing: 12) {
                    ForEach(viewModel.participants) { participant in
                        if let summary = result.summariesByParticipant[participant.id] {
                            ParticipantSummaryCardView(
                                participant: participant,
                                summary: summary,
                                items: viewModel.items,
                                itemAllocations: result.itemAllocations
                            )
                        }
                    }
                }

                ShareLink(item: viewModel.shareableSummaryText) {
                    Label("Compartir Resumen", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            } else {
                emptyGuidanceView
            }
        }
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack {
            Label("Resumen por Persona", systemImage: "chart.pie.fill")
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()
        }
    }

    private func reconciliationBadge(result: ReceiptSplitResult) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .font(.body)

            VStack(alignment: .leading, spacing: 2) {
                Text("Cuenta reconciliada al centavo exacto")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Text("Total general: \(MoneyFormatter.string(from: viewModel.grandTotal))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cuenta reconciliada al centavo exacto. Total general: \(MoneyFormatter.string(from: viewModel.grandTotal))")
    }

    private var emptyGuidanceView: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Resumen no disponible")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Text("Agrega comensales y al menos un artículo para calcular el desglose exacto por persona.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#Preview("Con Datos") {
    let vm = ReceiptEditorViewModel()
    let p1 = try! Participant(name: "Ana")
    let p2 = try! Participant(name: "Beto")
    vm.participants = [p1, p2]
    vm.items = [
        try! ReceiptItem(
            name: "Pizza Margherita",
            unitPrice: Money(amountInMinorUnits: 20000, currency: .mxn),
            quantity: 1,
            splitMode: .equal([p1.id, p2.id])
        )
    ]
    vm.taxText = "32.00"

    return ScrollView {
        SplitSummarySectionView(viewModel: vm)
            .padding()
    }
}

#Preview("Vacío") {
    let vm = ReceiptEditorViewModel()
    return ScrollView {
        SplitSummarySectionView(viewModel: vm)
            .padding()
    }
}
