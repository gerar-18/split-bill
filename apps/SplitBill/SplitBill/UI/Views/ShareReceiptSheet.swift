import SwiftUI

/// Modal allowing the host to publish a local receipt as a live QR/link collaborative session.
struct ShareReceiptSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var editorViewModel: ReceiptEditorViewModel
    @Bindable var collaborationViewModel: SharedSessionViewModel

    @State private var hostDisplayName: String = ""
    @State private var includeImageOptIn: Bool = false
    @State private var didCopyCode: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                if let snapshot = collaborationViewModel.activeSnapshot,
                   let shareCode = collaborationViewModel.activeShareCode,
                   collaborationViewModel.isHost {
                    activeSessionSections(snapshot: snapshot, shareCode: shareCode)
                } else {
                    publishSetupSections
                }

                if let errorMessage = collaborationViewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Compartir en Vivo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if hostDisplayName.isEmpty {
                    hostDisplayName = editorViewModel.participants.first?.name ?? ""
                }
            }
        }
    }

    // MARK: - Setup Sections

    @ViewBuilder
    private var publishSetupSections: some View {
        Section {
            TextField("Tu nombre (Ej. Gera)", text: $hostDisplayName)
                .textInputAutocapitalization(.words)
                .accessibilityLabel("Nombre del anfitrión")
        } header: {
            Text("Identidad en la mesa")
        } footer: {
            Text("No requiere iniciar sesión. Tus amigos solo verán este nombre junto a los artículos.")
        }

        Section {
            Toggle(isOn: $includeImageOptIn) {
                Label("Incluir foto del recibo", systemImage: "photo")
            }
            .disabled(!editorViewModel.hasReceiptImage)
        } header: {
            Text("Privacidad (Opt-in)")
        } footer: {
            Text(
                editorViewModel.hasReceiptImage
                ? "Desactivado por defecto para proteger tus datos. Si lo activas, la foto se comprime y se borra automáticamente a las 24h o al cerrar la sesión."
                : "No hay foto adjunta en este recibo."
            )
        }

        Section {
            HStack {
                Text("Artículos a compartir")
                Spacer()
                Text("\(editorViewModel.items.count)")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Total")
                Spacer()
                Text(MoneyFormatter.string(from: editorViewModel.grandTotal))
                    .fontWeight(.semibold)
            }

            Button {
                Task {
                    await collaborationViewModel.publishSession(
                        from: editorViewModel,
                        hostDisplayName: hostDisplayName,
                        includeImage: includeImageOptIn
                    )
                }
            } label: {
                HStack {
                    Spacer()
                    if collaborationViewModel.isLoading {
                        ProgressView()
                            .padding(.trailing, 6)
                    }
                    Label("Generar QR y Código", systemImage: "qrcode")
                        .fontWeight(.semibold)
                    Spacer()
                }
            }
            .disabled(collaborationViewModel.isLoading || editorViewModel.items.isEmpty)
        }
    }

    // MARK: - Active Session Sections

    @ViewBuilder
    private func activeSessionSections(
        snapshot: CollaborationSnapshotDTO,
        shareCode: ShareCode
    ) -> some View {
        Section {
            VStack(spacing: 14) {
                if let url = collaborationViewModel.shareURL,
                   let qrImage = QRCodeGenerator.generate(from: url.absoluteString, dimension: 220) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .padding(12)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel("Código QR para unirse a la cuenta")
                }

                VStack(spacing: 4) {
                    Text("Código de Mesa")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(shareCode.value)
                        .font(.system(.title2, design: .monospaced).bold())
                        .tracking(2)
                }

                HStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = shareCode.value
                        didCopyCode = true
                    } label: {
                        Label(didCopyCode ? "Copiado" : "Copiar Código", systemImage: didCopyCode ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.bordered)

                    if let shareURL = collaborationViewModel.shareURL {
                        ShareLink(
                            item: shareURL,
                            subject: Text("Únete a dividir \(snapshot.receipt.title)"),
                            message: Text("Usa el código \(shareCode.value) en SplitBill para elegir lo que pediste.")
                        ) {
                            Label("Enviar Enlace", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } header: {
            Text("Comparte con tus amigos")
        } footer: {
            Text("Válido por 24 horas. Tus amigos se unen sin crear cuenta.")
        }

        Section("Conectados (\(snapshot.receipt.participants.count))") {
            ForEach(snapshot.receipt.participants) { participant in
                HStack {
                    Image(systemName: participant.isHost ? "crown.fill" : "person.fill")
                        .foregroundStyle(participant.isHost ? .orange : .accentColor)
                    Text(participant.name)
                    Spacer()
                    if participant.isHost {
                        Text("Anfitrión")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button {
                dismiss()
                collaborationViewModel.isShowingLiveSessionSheet = true
            } label: {
                Label("Ver reclamos en tiempo real", systemImage: "list.bullet.rectangle")
            }
        }

        Section {
            Button(role: .destructive) {
                Task {
                    await collaborationViewModel.closeActiveSession()
                }
            } label: {
                Label("Cerrar sesión compartida", systemImage: "xmark.circle")
            }
        }
    }
}
