import SwiftUI

struct ReportSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var collaborationViewModel: SharedSessionViewModel

    @State private var selectedReason: ModerationReportReason = .inappropriateImage
    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Motivo del reporte") {
                    Picker("Motivo", selection: $selectedReason) {
                        ForEach(ModerationReportReason.allCases) { reason in
                            Text(label(for: reason)).tag(reason)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    TextField("Detalles adicionales (opcional)", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                        .onChange(of: note) { _, newValue in
                            if newValue.count > 300 {
                                note = String(newValue.prefix(300))
                            }
                        }
                } header: {
                    Text("Detalles (\(note.count)/300)")
                } footer: {
                    Text("Tu reporte es anónimo. Si una sesión recibe múltiples reportes, el servidor la suspende automáticamente.")
                }

                if let errorMessage = collaborationViewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task {
                            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                            await collaborationViewModel.submitReport(
                                reason: selectedReason,
                                note: trimmed.isEmpty ? nil : trimmed
                            )
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if collaborationViewModel.isLoading {
                                ProgressView()
                            } else {
                                Text("Enviar Reporte")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(collaborationViewModel.isLoading)
                }
            }
            .navigationTitle("Reportar Contenido")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func label(for reason: ModerationReportReason) -> String {
        switch reason {
        case .inappropriateImage:
            return "Imagen inapropiada o explícita"
        case .spamOrScam:
            return "Spam, fraude o enlace sospechoso"
        case .harassmentOrOffensiveText:
            return "Texto ofensivo o acoso"
        case .other:
            return "Otro motivo"
        }
    }
}

#Preview {
    ReportSessionSheet(collaborationViewModel: SharedSessionViewModel())
}
