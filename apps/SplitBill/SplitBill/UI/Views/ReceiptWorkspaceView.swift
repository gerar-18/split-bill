import SwiftUI

/// The unified workspace screen for SplitBill assembling all modular sections:
/// Participants, Receipt Items, Tax & Tip, and the Final Per-Person Split Summary.
struct ReceiptWorkspaceView: View {

    // MARK: - Bindings & State

    @Bindable var viewModel: ReceiptEditorViewModel
    @State private var showResetConfirmation = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    sectionCard {
                        ParticipantsSectionView(viewModel: viewModel)
                    }

                    sectionCard {
                        ReceiptItemsSectionView(viewModel: viewModel)
                    }

                    sectionCard {
                        TaxAndTipSectionView(viewModel: viewModel)
                    }

                    sectionCard {
                        SplitSummarySectionView(viewModel: viewModel)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("SplitBill")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if viewModel.splitResult != nil && !viewModel.items.isEmpty {
                        ShareLink(item: viewModel.shareableSummaryText) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Compartir resumen de la cuenta")
                    }

                    Button {
                        showResetConfirmation = true
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .accessibilityLabel("Reiniciar cuenta")
                }
            }
            .confirmationDialog(
                "¿Reiniciar cuenta?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reiniciar todo", role: .destructive) {
                    viewModel.reset()
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Esta acción borrará todos los comensales, artículos y cálculos registrados. No se puede deshacer.")
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
