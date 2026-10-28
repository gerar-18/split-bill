import SwiftUI

/// Section view displaying the list of items registered on the receipt, an empty guidance state,
/// and buttons to trigger new item creation or existing item editing.
struct ReceiptItemsSectionView: View {

    // MARK: - State & Bindings

    @Bindable var viewModel: ReceiptEditorViewModel
    @State private var itemPendingDeletion: ReceiptItem? = nil

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with title, counter badge, and add button
            headerRow

            // Items List or Empty Guidance State
            if viewModel.items.isEmpty {
                emptyGuidanceView
            } else {
                itemsList
            }
        }
        .sheet(item: $viewModel.activeItemDraft) { _ in
            ReceiptItemEditorSheet(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "¿Eliminar artículo?",
            item: $itemPendingDeletion
        ) { item in
            Button("Eliminar \(item.name)", role: .destructive) {
                viewModel.deleteItem(id: item.id)
            }
        } message: { item in
            Text("¿Estás seguro de que deseas eliminar \"\(item.name)\"? Esta acción no se puede deshacer.")
        }
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack {
            Label("Artículos del Recibo", systemImage: "cart.fill")
                .font(.headline)
                .foregroundStyle(.primary)

            if !viewModel.items.isEmpty {
                Text("\(viewModel.items.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: .capsule)
            }

            Spacer()

            Button {
                viewModel.openNewItemDraft()
            } label: {
                Label("Agregar artículo", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.participants.isEmpty)
            .help(viewModel.participants.isEmpty ? "Agrega comensales antes de registrar artículos" : "Agregar un nuevo artículo a la cuenta")
            .frame(minHeight: 44)
        }
    }

    private var emptyGuidanceView: some View {
        ContentUnavailableView(
            "Sin artículos",
            systemImage: "cart.badge.plus",
            description: Text(
                viewModel.participants.isEmpty
                    ? "Agrega primero a los comensales para comenzar a registrar artículos."
                    : "Agrega los platillos y bebidas para comenzar a dividirlos."
            )
        )
        .frame(maxWidth: .infinity, minHeight: 140)
    }

    private var itemsList: some View {
        VStack(spacing: 8) {
            ForEach(viewModel.items) { item in
                HStack(spacing: 8) {
                    Button {
                        viewModel.openEditItemDraft(item)
                    } label: {
                        ReceiptItemRowView(item: item, participants: viewModel.participants)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button("Eliminar \(item.name)", systemImage: "trash") {
                        itemPendingDeletion = item
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Eliminar \(item.name)")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.background.secondary, in: .rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
                )
            }
        }
    }
}

// MARK: - Previews

#Preview("Populated Items") {
    let vm = ReceiptEditorViewModel()
    vm.newParticipantName = "Ana"
    vm.addParticipant()
    vm.newParticipantName = "Carlos"
    vm.addParticipant()

    if let p1 = vm.participants.first, let p2 = vm.participants.last {
        if let item1 = try? ReceiptItem(
            name: "Guacamole y Totopos",
            unitPrice: Money(amountInMinorUnits: 14000, currency: .mxn),
            quantity: 1,
            splitMode: .equal([p1.id, p2.id])
        ),
        let item2 = try? ReceiptItem(
            name: "Tacos al Pastor",
            unitPrice: Money(amountInMinorUnits: 18000, currency: .mxn),
            quantity: 2,
            splitMode: .wholeItem(p1.id)
        ) {
            vm.items = [item1, item2]
        }
    }

    return ScrollView {
        ReceiptItemsSectionView(viewModel: vm)
            .padding()
    }
}

#Preview("Empty Items - With Participants") {
    let vm = ReceiptEditorViewModel()
    vm.newParticipantName = "Ana"
    vm.addParticipant()

    return ScrollView {
        ReceiptItemsSectionView(viewModel: vm)
            .padding()
    }
}

#Preview("Empty Items - No Participants") {
    let vm = ReceiptEditorViewModel()
    return ScrollView {
        ReceiptItemsSectionView(viewModel: vm)
            .padding()
    }
}
