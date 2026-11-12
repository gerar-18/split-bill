import SwiftUI

/// Hoja modal accesible para recabar consentimiento informado previo al análisis con IA (Apple Guideline 5.1.2(i)).
struct AIConsentSheet: View {
    @Bindable var viewModel: ReceiptEditorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerView
                    informationCardView
                    actionButtonsView
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Extracción con IA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        viewModel.isShowingAIConsentSheet = false
                        dismiss()
                    }
                    .frame(minHeight: 44)
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.85), Color.blue.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 76, height: 76)
                    .shadow(color: Color.purple.opacity(0.25), radius: 8, y: 4)

                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            Text("Extracción Inteligente con IA")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)

            Text("Asistencia para estructurar platillos y subtotales complejos")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var informationCardView: some View {
        VStack(alignment: .leading, spacing: 16) {
            infoBullet(
                icon: "text.document",
                title: "¿Qué datos se envían?",
                description: "Únicamente el texto ya reconocido del ticket y la moneda seleccionada. Jamás tu fotografía original, ubicación, contactos ni información del dispositivo."
            )

            Divider()

            infoBullet(
                icon: "lock.shield",
                title: "¿Quién los procesa?",
                description: "El servicio seguro de SplitBill (compatible con DeepSeek, modelos locales u otros proveedores seguros). Los datos se utilizan estrictamente para estructurar esta cuenta y nunca para entrenar modelos externos de IA."
            )

            Divider()

            infoBullet(
                icon: "slider.horizontal.3",
                title: "Control y Revisión Total",
                description: "Podrás revisar, editar cantidades, ajustar precios y deseleccionar elementos en la pantalla de revisión interactiva antes de importarlos."
            )

            Divider()

            infoBullet(
                icon: "arrow.uturn.backward.circle",
                title: "Revocable en cualquier momento",
                description: "Puedes revocar o cambiar tu consentimiento cuando lo desees desde la pantalla Acerca de y Privacidad."
            )
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private func infoBullet(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.purple)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await viewModel.grantAIConsentAndParse()
                    dismiss()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Aceptar y Analizar con IA")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .accessibilityLabel("Aceptar consentimiento y analizar recibo con inteligencia artificial")

            Button {
                viewModel.isShowingAIConsentSheet = false
                dismiss()
            } label: {
                Text("Cancelar")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Cancelar análisis con IA y mantener extracción local")
        }
        .padding(.top, 8)
    }
}
