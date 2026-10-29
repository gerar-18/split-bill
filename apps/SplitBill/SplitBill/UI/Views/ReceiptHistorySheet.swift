import SwiftUI

/// Modal sheet presenting saved receipt history, allowing the user to switch between accounts,
/// delete previous sessions via swipe actions, or start a new account.
struct ReceiptHistorySheet: View {

    // MARK: - Bindings & Environment

    @Bindable var viewModel: ReceiptEditorViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.savedReceipts.isEmpty {
                    emptyHistoryView
                } else {
                    historyList
                }
            }
            .navigationTitle("Mis Cuentas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.startNewReceipt()
                        dismiss()
                    } label: {
                        Label("Nueva Cuenta", systemImage: "plus")
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var emptyHistoryView: some View {
        ContentUnavailableView(
            "Sin Cuentas Guardadas",
            systemImage: "clock.arrow.circlepath",
            description: Text("Las cuentas que crees se guardarán automáticamente aquí.")
        )
    }

    private var historyList: some View {
        List {
            ForEach(viewModel.savedReceipts) { snapshot in
                Button {
                    viewModel.selectReceipt(id: snapshot.id)
                    dismiss()
                } label: {
                    receiptRow(for: snapshot)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.deleteSavedReceipt(id: snapshot.id)
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func receiptRow(for snapshot: ReceiptSnapshot) -> some View {
        let trimmedTitle = snapshot.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let isUntitled = trimmedTitle.isEmpty
        let displayTitle = isUntitled ? "Cuenta sin título" : trimmedTitle
        let isActive = snapshot.id == viewModel.receiptID
        let personsCount = snapshot.participants.count
        let itemsCount = snapshot.items.count
        let personsText = personsCount == 1 ? "1 persona" : "\(personsCount) personas"
        let itemsText = itemsCount == 1 ? "1 artículo" : "\(itemsCount) artículos"

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(displayTitle)
                        .font(.headline)
                        .foregroundStyle(isUntitled ? .secondary : .primary)
                        .italic(isUntitled)
                        .lineLimit(1)

                    if isActive {
                        Text("Activa")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.tint, in: .capsule)
                    }
                }

                HStack(spacing: 4) {
                    Text(snapshot.updatedAt, format: .relative(presentation: .named))
                    Text("•")
                    Text("\(personsText) • \(itemsText)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(MoneyFormatter.string(from: snapshot.grandTotal))
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(displayTitle)\(isActive ? ", cuenta activa" : ""), \(MoneyFormatter.string(from: snapshot.grandTotal)), \(personsText), \(itemsText), actualizada \(snapshot.updatedAt.formatted(.relative(presentation: .named)))"
        )
        .accessibilityHint("Toca dos veces para abrir y editar esta cuenta")
    }
}

// MARK: - Preview

#Preview {
    let store = (try? SwiftDataReceiptStore.inMemory()) ?? SwiftDataReceiptStore.live()
    let p1 = try! Participant(name: "Ana")
    let p2 = try! Participant(name: "Carlos")
    let item = try! ReceiptItem(
        name: "Hamburguesa Clásica",
        unitPrice: Money(amountInMinorUnits: 18000, currency: .mxn),
        quantity: 2,
        splitMode: .equal([p1.id, p2.id])
    )
    let snap1 = ReceiptSnapshot(
        title: "Cena Taquería",
        updatedAt: Date().addingTimeInterval(-1800),
        participants: [p1, p2],
        items: [item]
    )
    let snap2 = ReceiptSnapshot(
        title: "",
        updatedAt: Date().addingTimeInterval(-86400),
        participants: [p1],
        items: []
    )
    try? store.save(snap1)
    try? store.save(snap2)

    let vm = ReceiptEditorViewModel(store: store)
    return ReceiptHistorySheet(viewModel: vm)
}
