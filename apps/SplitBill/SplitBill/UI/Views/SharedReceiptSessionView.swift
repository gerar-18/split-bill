import SwiftUI

struct SharedReceiptSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var collaborationViewModel: SharedSessionViewModel
    @State private var showBlockConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                if let banner = collaborationViewModel.statusBanner {
                    Section {
                        Label(banner, systemImage: "info.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage = collaborationViewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if let snapshot = collaborationViewModel.activeSnapshot {
                    if snapshot.domainStatus == .quarantined {
                        Section {
                            ContentUnavailableView(
                                "Sesión suspendida por moderación",
                                systemImage: "exclamationmark.shield.fill",
                                description: Text("El contenido compartido fue ocultado tras recibir múltiples reportes.")
                            )
                            Button("Bloquear sesión y salir", role: .destructive) {
                                showBlockConfirmation = true
                            }
                        }
                    } else {
                        headerSection(snapshot: snapshot)

                        if let image = collaborationViewModel.decodedOptInImage {
                            Section("Foto del Recibo (Opt-In)") {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 240)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        itemsSection(snapshot: snapshot)

                        if let preview = collaborationViewModel.domainPreview {
                            totalsBreakdownSection(preview: preview)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "Sin sesión activa",
                        systemImage: "person.2.slash",
                        description: Text("Únete con un código o comparte un recibo para comenzar.")
                    )
                }
            }
            .navigationTitle(collaborationViewModel.activeSnapshot?.receipt.title ?? "Cuenta en Vivo")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await collaborationViewModel.refreshSnapshot()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
                if collaborationViewModel.activeSnapshot != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            if collaborationViewModel.shouldDisplayReceiptImage {
                                Button {
                                    collaborationViewModel.hideImageLocally()
                                } label: {
                                    Label("Ocultar imagen del recibo", systemImage: "eye.slash")
                                }
                            }
                            Button {
                                collaborationViewModel.isShowingReportSheet = true
                            } label: {
                                Label("Reportar contenido inapropiado", systemImage: "flag")
                            }
                            Button(role: .destructive) {
                                showBlockConfirmation = true
                            } label: {
                                Label("Bloquear sesión y salir", systemImage: "hand.raised")
                            }
                        } label: {
                            Label("Opciones de seguridad", systemImage: "ellipsis.circle")
                        }
                        .accessibilityLabel("Opciones de seguridad")
                    }
                }
            }
            .sheet(isPresented: $collaborationViewModel.isShowingReportSheet) {
                ReportSessionSheet(collaborationViewModel: collaborationViewModel)
            }
            .confirmationDialog(
                "¿Bloquear esta sesión compartida?",
                isPresented: $showBlockConfirmation,
                titleVisibility: .visible
            ) {
                Button("Bloquear y salir", role: .destructive) {
                    Task {
                        await collaborationViewModel.blockAndLeaveSession()
                    }
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Dejarás de ver esta cuenta compartida y no volverá a abrirse mediante enlaces.")
            }
        }
    }

    @ViewBuilder
    private func headerSection(snapshot: CollaborationSnapshotDTO) -> some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Código: \(snapshot.shareCode)")
                        .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    Text("Participantes: \(collaborationViewModel.domainParticipants.map(\.name).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if collaborationViewModel.isMutatingClaim {
                    ProgressView()
                }
            }
        }
    }

    @ViewBuilder
    private func itemsSection(snapshot: CollaborationSnapshotDTO) -> some View {
        Section("Ítems del Recibo") {
            let myID = collaborationViewModel.myParticipantID
            let isEditable = snapshot.domainStatus == .active

            ForEach(collaborationViewModel.domainItems) { item in
                let isMine = myID.map { item.claimantIDs.contains($0) } ?? false
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(item.name)
                                .font(.body.weight(.medium))
                            if item.quantity > 1 {
                                Text("×\(item.quantity)")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.15), in: Capsule())
                            }
                        }

                        Text(claimSubtitle(for: item))
                            .font(.caption)
                            .foregroundStyle(item.claimantIDs.isEmpty ? .orange : .secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        Text(MoneyFormatter.string(from: item.lineTotal))
                            .font(.subheadline.weight(.semibold).monospacedDigit())

                        Button {
                            Task {
                                await collaborationViewModel.toggleClaim(forItemID: item.id)
                            }
                        } label: {
                            Text(isMine ? "Quitar" : "Yo pedí esto")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(isMine ? .gray : .accentColor)
                        .disabled(!isEditable || collaborationViewModel.isMutatingClaim)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private func totalsBreakdownSection(preview: CollaborationSplitPreview) -> some View {
        Section("Desglose en Vivo") {
            ForEach(collaborationViewModel.domainParticipants) { participant in
                if let summary = preview.splitResult.summariesByParticipant[participant.id] {
                    let isMe = participant.id == collaborationViewModel.myParticipantID
                    HStack {
                        Text(isMe ? "\(participant.name) (Tú)" : participant.name)
                            .font(isMe ? .body.weight(.semibold) : .body)
                        Spacer()
                        Text(MoneyFormatter.string(from: summary.total))
                            .font(.body.weight(.semibold).monospacedDigit())
                    }
                }
            }

            if preview.unclaimedSubtotal.amountInMinorUnits > 0 {
                HStack {
                    Text("Pendiente de asignar (\(preview.unclaimedItemIDs.count) ítems)")
                        .foregroundStyle(.orange)
                    Spacer()
                    Text(MoneyFormatter.string(from: preview.unclaimedSubtotal))
                        .foregroundStyle(.orange)
                        .monospacedDigit()
                }
            }

            HStack {
                Text("Total del Recibo")
                    .fontWeight(.bold)
                Spacer()
                Text(MoneyFormatter.string(from: preview.grandTotal))
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
        }
    }

    private func claimSubtitle(for item: SharedReceiptLineItem) -> String {
        switch item.claimantIDs.count {
        case 0:
            return "Sin asignar"
        case 1:
            if let id = item.claimantIDs.first,
               let name = collaborationViewModel.domainParticipants.first(where: { $0.id == id })?.name {
                return id == collaborationViewModel.myParticipantID ? "Solo tú" : "Solo \(name)"
            }
            return "1 persona"
        default:
            return "Dividido entre \(item.claimantIDs.count) personas"
        }
    }
}

#Preview {
    SharedReceiptSessionView(collaborationViewModel: SharedSessionViewModel())
}
