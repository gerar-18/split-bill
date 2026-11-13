import SwiftUI

struct JoinSharedReceiptSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var collaborationViewModel: SharedSessionViewModel

    @State private var codeInput: String = ""
    @State private var displayName: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Código de 8 caracteres", text: $codeInput)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.title3, design: .monospaced).weight(.semibold))
                        .onChange(of: codeInput) { _, newValue in
                            let cleaned = newValue
                                .uppercased()
                                .filter { !$0.isWhitespace && !$0.isNewline }
                            if cleaned != newValue {
                                codeInput = String(cleaned.prefix(8))
                            } else if cleaned.count > 8 {
                                codeInput = String(cleaned.prefix(8))
                            }
                        }

                    TextField("Tu nombre (ej. Sofía)", text: $displayName)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Unirse sin crear cuenta")
                } footer: {
                    Text("Tu nombre solo se usa en esta cuenta compartida temporal para saber qué ítems elegiste.")
                }

                if let errorMessage = collaborationViewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task {
                            await collaborationViewModel.joinSession(
                                rawCode: codeInput,
                                displayName: displayName
                            )
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if collaborationViewModel.isLoading {
                                ProgressView()
                            } else {
                                Text("Unirse a la Cuenta")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(
                        collaborationViewModel.isLoading
                            || codeInput.trimmingCharacters(in: .whitespacesAndNewlines).count != 8
                            || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
            .navigationTitle("Unirse a Cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        collaborationViewModel.prefilledJoinCode = ""
                        dismiss()
                    }
                }
            }
            .onAppear {
                if codeInput.isEmpty && !collaborationViewModel.prefilledJoinCode.isEmpty {
                    codeInput = collaborationViewModel.prefilledJoinCode
                    collaborationViewModel.prefilledJoinCode = ""
                }
            }
        }
    }
}

#Preview {
    JoinSharedReceiptSheet(collaborationViewModel: SharedSessionViewModel())
}
