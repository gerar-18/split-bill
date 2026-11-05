import SwiftUI

/// The unified workspace screen for SplitBill assembling all modular sections:
/// Account Title, Participants, Receipt Items, Tax & Tip, and the Final Per-Person Split Summary.
struct ReceiptWorkspaceView: View {

    // MARK: - Bindings & State

    @Bindable var viewModel: ReceiptEditorViewModel
    @State private var isHistoryPresented = false
    @State private var showNewReceiptConfirmation = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Section 0: Account Title
                    sectionCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Nombre de la Cuenta", systemImage: "pencil.and.list.clipboard")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            TextField("Ej. Cena Taquería, Salida al Cine...", text: $viewModel.receiptTitle)
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.sentences)
                                .autocorrectionDisabled(false)
                                .accessibilityLabel("Nombre de la cuenta")
                        }
                    }

                    // Section 1: Receipt Photo & Inspection
                    sectionCard {
                        ReceiptImageSectionView(viewModel: viewModel)
                    }

                    // Section 2: Participants & Currency
                    sectionCard {
                        ParticipantsSectionView(viewModel: viewModel)
                    }

                    // Section 3: Items & Assignments
                    sectionCard {
                        ReceiptItemsSectionView(viewModel: viewModel)
                    }

                    // Section 4: Tax & Tip
                    sectionCard {
                        TaxAndTipSectionView(viewModel: viewModel)
                    }

                    // Section 5: Split Summary
                    sectionCard {
                        SplitSummarySectionView(viewModel: viewModel)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("SplitBill")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isHistoryPresented = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel(
                        "Mis cuentas guardadas, \(viewModel.savedReceipts.count == 1 ? "1 disponible" : "\(viewModel.savedReceipts.count) disponibles")"
                    )
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    if viewModel.splitResult != nil && !viewModel.items.isEmpty {
                        ShareLink(item: viewModel.shareableSummaryText) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Compartir resumen de la cuenta")
                    }

                    Button {
                        if !viewModel.participants.isEmpty || !viewModel.items.isEmpty || !viewModel.receiptTitle.isEmpty || viewModel.hasReceiptImage {
                            showNewReceiptConfirmation = true
                        } else {
                            viewModel.startNewReceipt()
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Iniciar nueva cuenta")
                }
            }
            .sheet(isPresented: $isHistoryPresented) {
                ReceiptHistorySheet(viewModel: viewModel)
            }
            .confirmationDialog(
                "¿Iniciar nueva cuenta?",
                isPresented: $showNewReceiptConfirmation,
                titleVisibility: .visible
            ) {
                Button("Nueva cuenta", role: .destructive) {
                    viewModel.startNewReceipt()
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Se preparará un espacio en blanco. La cuenta actual permanece guardada en tu historial.")
            }
        }
    }

    // MARK: - Card Container Helper

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Preview

#Preview {
    let vm = ReceiptEditorViewModel()
    let p1 = try! Participant(name: "Ana")
    let p2 = try! Participant(name: "Carlos")
    vm.participants = [p1, p2]
    vm.items = [
        try! ReceiptItem(
            name: "Hamburguesa Clásica",
            unitPrice: Money(amountInMinorUnits: 18000, currency: .mxn),
            quantity: 2,
            splitMode: .equal([p1.id, p2.id])
        ),
        try! ReceiptItem(
            name: "Cerveza Artesanal",
            unitPrice: Money(amountInMinorUnits: 8500, currency: .mxn),
            quantity: 1,
            splitMode: .wholeItem(p1.id)
        )
    ]
    vm.taxText = "71.20"

    return ReceiptWorkspaceView(viewModel: vm)
}
