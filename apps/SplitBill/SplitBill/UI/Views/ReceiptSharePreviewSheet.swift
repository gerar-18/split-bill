import SwiftUI

/// Interactive preview sheet enabling the user to customize the receipt infographic card
/// (Theme and Itemized detail) and share it as a high-resolution PNG image or plain text.
struct ReceiptSharePreviewSheet: View {

    // MARK: - Properties & Bindings

    @Environment(\.dismiss) private var dismiss
    let viewModel: ReceiptEditorViewModel

    @State private var selectedTheme: ReceiptCardTheme = .classicLight
    @State private var showsItemizedDetails: Bool = true
    @State private var renderedImage: UIImage? = nil
    @State private var renderedPNGData: Data? = nil

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let cardData = viewModel.shareCardData {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Controls Section: Theme Picker & Detail Toggle
                            controlsSection

                            // Card Live Preview
                            ReceiptShareCardView(
                                data: cardData,
                                theme: selectedTheme,
                                showsItemizedDetails: showsItemizedDetails
                            )
                            .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                            .padding(.vertical, 8)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    // Bottom Action Bar
                    bottomActionBar(cardData: cardData)
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Tarjeta del Recibo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        dismiss()
                    }
                    .accessibilityLabel("Cerrar ventana de compartir")
                }
            }
            .task(id: "\(selectedTheme.rawValue)-\(showsItemizedDetails)") {
                updateRenderedOutputs()
            }
        }
    }

    // MARK: - Subviews

    private var controlsSection: some View {
        VStack(spacing: 12) {
            Picker("Tema", selection: $selectedTheme) {
                ForEach(ReceiptCardTheme.allCases) { theme in
                    Text(theme.rawValue).tag(theme)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Seleccionar tema de la tarjeta")

            Toggle("Incluir detalle de platillos", isOn: $showsItemizedDetails)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .accessibilityLabel("Alternar inclusión de platillos detallados")
        }
        .padding(12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func bottomActionBar(cardData: ReceiptShareCardData) -> some View {
        VStack(spacing: 8) {
            Divider()

            if let pngData = renderedPNGData, let uiImage = renderedImage {
                let shareable = ShareableReceiptImage(pngData: pngData, title: cardData.title)
                ShareLink(
                    item: shareable,
                    preview: SharePreview(cardData.title, image: Image(uiImage: uiImage))
                ) {
                    Label("Compartir Tarjeta (Imagen)", systemImage: "photo.badge.arrow.down")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Compartir tarjeta como imagen PNG en alta resolución")
            } else {
                ProgressView("Generando imagen...")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }

            ShareLink(item: viewModel.shareableSummaryText) {
                Label("Compartir como Texto", systemImage: "doc.plaintext")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 36)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Compartir resumen en texto plano")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.background.secondary)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No hay datos suficientes para generar la tarjeta.")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Asegúrate de tener al menos un comensal y un artículo registrado.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxHeight: .infinity)
    }

    // MARK: - Rendering Helper

    private func updateRenderedOutputs() {
        guard let cardData = viewModel.shareCardData else { return }
        if let image = ReceiptCardRenderer.renderImage(
            data: cardData,
            theme: selectedTheme,
            showsItemizedDetails: showsItemizedDetails
        ) {
            self.renderedImage = image
            self.renderedPNGData = image.pngData()
        }
    }
}

// MARK: - Preview

#Preview {
    let vm = ReceiptEditorViewModel()
    let p1 = try! Participant(name: "Ana García")
    let p2 = try! Participant(name: "Carlos Rivera")
    vm.participants = [p1, p2]
    vm.items = [
        try! ReceiptItem(
            name: "Pizza Familiar",
            unitPrice: Money(amountInMinorUnits: 28000, currency: .mxn),
            quantity: 1,
            splitMode: .equal([p1.id, p2.id])
        ),
        try! ReceiptItem(
            name: "Refresco",
            unitPrice: Money(amountInMinorUnits: 4500, currency: .mxn),
            quantity: 2,
            splitMode: .equal([p1.id, p2.id])
        )
    ]
    vm.taxText = "59.20"

    return ReceiptSharePreviewSheet(viewModel: vm)
}
