import SwiftUI

/// The unified workspace screen for SplitBill assembling all modular sections:
/// Account Title, Participants, Receipt Items, Tax & Tip, and the Final Per-Person Split Summary.
struct ReceiptWorkspaceView: View {

    // MARK: - Bindings & State

    @Bindable var viewModel: ReceiptEditorViewModel
    var collaborationViewModel: SharedSessionViewModel = SharedSessionViewModel()
    @State private var isHistoryPresented = false
    @State private var isAboutPresented = false
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
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        isHistoryPresented = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel(
                        "Mis cuentas guardadas, \(viewModel.savedReceipts.count == 1 ? "1 disponible" : "\(viewModel.savedReceipts.count) disponibles")"
                    )

                    Button {
                        isAboutPresented = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("Acerca de SplitBill y Privacidad")
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        if !viewModel.items.isEmpty {
                            Button {
                                collaborationViewModel.isShowingShareSheet = true
                            } label: {
                                Label("Compartir en Vivo (QR)", systemImage: "qrcode")
                            }
                        }

                        Button {
                            collaborationViewModel.openJoinFlow()
                        } label: {
                            Label("Unirse con Código", systemImage: "person.badge.plus")
                        }

                        if viewModel.splitResult != nil && !viewModel.items.isEmpty {
                            Divider()

                            Button {
                                viewModel.isShowingSharePreviewSheet = true
                            } label: {
                                Label("Tarjeta Visual (Imagen)", systemImage: "sparkles.rectangle.stack")
                            }

                            ShareLink(item: viewModel.shareableSummaryText) {
                                Label("Resumen en Texto", systemImage: "doc.plaintext")
                            }
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Opciones para compartir y colaborar")

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
            .sheet(isPresented: $isAboutPresented) {
                AboutPrivacySheet()
            }
            .sheet(isPresented: $viewModel.isShowingSharePreviewSheet) {
                ReceiptSharePreviewSheet(viewModel: viewModel)
            }
            .sheet(isPresented: Bindable(collaborationViewModel).isShowingShareSheet) {
                ShareReceiptSheet(
                    editorViewModel: viewModel,
                    collaborationViewModel: collaborationViewModel
                )
            }
            .sheet(isPresented: Bindable(collaborationViewModel).isShowingJoinSheet) {
                JoinSharedReceiptSheet(collaborationViewModel: collaborationViewModel)
            }
            .sheet(isPresented: Bindable(collaborationViewModel).isShowingLiveSessionSheet) {
                SharedReceiptSessionView(collaborationViewModel: collaborationViewModel)
            }
            .alert(
                "Cuenta Compartida",
                isPresented: Binding(
                    get: {
                        !collaborationViewModel.isShowingShareSheet
                            && !collaborationViewModel.isShowingJoinSheet
                            && !collaborationViewModel.isShowingLiveSessionSheet
                            && collaborationViewModel.errorMessage != nil
                    },
                    set: { isPresented in
                        if !isPresented {
                            collaborationViewModel.errorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    collaborationViewModel.errorMessage = nil
                }
            } message: {
                Text(collaborationViewModel.errorMessage ?? "")
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
