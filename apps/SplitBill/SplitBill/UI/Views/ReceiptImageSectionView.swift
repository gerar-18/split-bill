import PhotosUI
import SwiftUI

/// Section view for attaching, previewing, and managing physical or digital receipt tickets.
/// Supports camera capture (on physical devices), system photo library selection, and sample presets for simulator/testing.
struct ReceiptImageSectionView: View {

    // MARK: - Bindings & Local State

    @Bindable var viewModel: ReceiptEditorViewModel
    @State private var isViewerPresented = false
    @State private var isCameraPresented = false
    @State private var isPhotoPickerPresented = false
    @State private var isOCRSheetPresented = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showDeleteConfirmation = false
    @State private var isProcessingPhoto = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow

            if let imageData = viewModel.receiptImageData, let uiImage = UIImage(data: imageData) {
                attachedImageView(uiImage: uiImage, data: imageData)
            } else {
                emptyStateView
            }
        }
        .sheet(isPresented: $isViewerPresented) {
            if let data = viewModel.receiptImageData {
                ReceiptImageViewerSheet(
                    imageData: data,
                    title: viewModel.receiptTitle
                )
            }
        }
        .sheet(isPresented: $isCameraPresented) {
            CameraCaptureView { capturedData in
                viewModel.attachReceiptImageData(capturedData)
                Task { await viewModel.recognizeReceiptText() }
            }
        }
        .sheet(isPresented: $isOCRSheetPresented) {
            ReceiptOCRTextSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isShowingParsedReviewSheet) {
            ReceiptParsedReviewSheet(viewModel: viewModel)
        }
        .confirmationDialog(
            "¿Eliminar foto del recibo?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Eliminar foto", role: .destructive) {
                viewModel.removeReceiptImage()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("La imagen se eliminará de esta cuenta. Los participantes y artículos registrados se conservarán.")
        }
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            loadSelectedPhoto(newItem)
        }
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack {
            Label("Foto del Recibo", systemImage: "doc.text.image")
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            if viewModel.hasReceiptImage {
                Menu {
                    replaceMenuContent
                } label: {
                    Label("Cambiar", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .disabled(isProcessingPhoto)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "camera.viewfinder")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Agrega una foto de tu ticket")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    Text("Consúltala en cualquier momento con zoom mientras asignas platillos.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            Divider()

            HStack(spacing: 8) {
                if CameraCaptureView.isCameraAvailable {
                    Button {
                        isCameraPresented = true
                    } label: {
                        Label("Cámara", systemImage: "camera.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Tomar foto con la cámara")
                }

                Button {
                    isPhotoPickerPresented = true
                } label: {
                    Label("Galería", systemImage: "photo.on.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Elegir foto de la galería")

                Menu {
                    Text("Tickets de Ejemplo")
                    ForEach(SampleReceiptPreset.allCases) { preset in
                        Button(preset.displayName) {
                            viewModel.attachSampleReceipt(preset)
                            Task { await viewModel.recognizeReceiptText() }
                        }
                    }
                } label: {
                    Label("Muestra", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Cargar ticket de ejemplo para pruebas")
            }
            .disabled(isProcessingPhoto)

            if isProcessingPhoto {
                ProgressView("Procesando imagen...")
                    .font(.caption)
                    .padding(.top, 4)
            }
        }
        .padding(12)
        .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func attachedImageView(uiImage: UIImage, data: Data) -> some View {
        VStack(spacing: 10) {
            Button {
                isViewerPresented = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
                        )

                    if isProcessingPhoto {
                        ZStack {
                            Color.black.opacity(0.4)
                            ProgressView("Procesando imagen...")
                                .tint(.white)
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                            Text("Ver con Zoom")
                        }
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.7), in: .capsule)
                        .padding(8)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isProcessingPhoto)
            .accessibilityLabel(
                isProcessingPhoto
                    ? "Procesando nueva foto del recibo..."
                    : "Foto adjunta del recibo. Toca para ver en pantalla completa con zoom."
            )

            ocrInspectionRow

            HStack {
                Button {
                    isViewerPresented = true
                } label: {
                    Label("Pantalla completa", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.caption.weight(.medium))
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)

                Spacer()

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Eliminar foto", systemImage: "trash")
                        .font(.caption.weight(.medium))
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 4)
            .disabled(isProcessingPhoto)
        }
    }

    @ViewBuilder
    private var ocrInspectionRow: some View {
        if viewModel.isRecognizingText {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Reconociendo texto del ticket...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.vertical, 4)
            .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 8))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Reconociendo texto del ticket con OCR en progreso")
        } else if viewModel.hasOCRText || viewModel.parsedCandidate != nil {
            ocrParsedActionsView
        } else {
            Button {
                Task {
                    await viewModel.recognizeReceiptText()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "text.viewfinder")
                    Text("Extraer texto del ticket (OCR)")
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Extraer texto del ticket con OCR")
        }
    }

    private var ocrParsedActionsView: some View {
        VStack(spacing: 8) {
            Button {
                viewModel.prepareParsedReceiptReview()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.subheadline.weight(.semibold))

                    let count = viewModel.detectedParsedItemCount
                    Text("Revisar e importar (\(count) \(count == 1 ? "platillo" : "platillos"))")
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    reconciliationBadge
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Revisar e importar \(viewModel.detectedParsedItemCount) platillos detectados del recibo")

            Button {
                isOCRSheetPresented = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "text.viewfinder")
                    Text("Ver texto OCR (\(viewModel.ocrLineCount) líneas)")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 36)
                .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ver texto OCR del ticket, \(viewModel.ocrLineCount) líneas encontradas")
        }
    }

    @ViewBuilder
    private var reconciliationBadge: some View {
        if let status = viewModel.detectedReconciliationStatus {
            switch status {
            case .verified:
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Verificado")
                }
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.2), in: Capsule())
            case .discrepancy(let diff, let currency):
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    let formatted = MoneyFormatter.string(from: Money(amountInMinorUnits: abs(diff), currency: currency), includeCurrencyCode: false)
                    Text("Δ \(formatted)")
                }
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.3), in: Capsule())
            case .partial:
                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill")
                    Text("Parcial")
                }
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.2), in: Capsule())
            case .empty:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var replaceMenuContent: some View {
        if CameraCaptureView.isCameraAvailable {
            Button {
                isCameraPresented = true
            } label: {
                Label("Tomar nueva foto", systemImage: "camera")
            }
        }

        Button {
            isPhotoPickerPresented = true
        } label: {
            Label("Elegir de galería", systemImage: "photo")
        }

        Menu {
            ForEach(SampleReceiptPreset.allCases) { preset in
                Button(preset.displayName) {
                    viewModel.attachSampleReceipt(preset)
                    Task { await viewModel.recognizeReceiptText() }
                }
            }
        } label: {
            Label("Usar ticket de muestra", systemImage: "sparkles")
        }

        Button {
            Task {
                await viewModel.recognizeReceiptText()
            }
        } label: {
            Label("Volver a escanear ticket", systemImage: "arrow.clockwise")
        }
        .disabled(viewModel.isRecognizingText)

        Divider()

        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label("Eliminar foto", systemImage: "trash")
        }
    }

    // MARK: - Actions

    private func loadSelectedPhoto(_ item: PhotosPickerItem) {
        isProcessingPhoto = true
        Task {
            do {
                if let rawData = try await item.loadTransferable(type: Data.self) {
                    viewModel.attachReceiptImageData(rawData)
                    isProcessingPhoto = false
                    await viewModel.recognizeReceiptText()
                } else {
                    viewModel.validationMessage = "No se pudo obtener la imagen seleccionada."
                    isProcessingPhoto = false
                }
            } catch {
                viewModel.validationMessage = "Error al cargar la foto seleccionada."
                isProcessingPhoto = false
            }
            selectedPhotoItem = nil
        }
    }
}

// MARK: - Previews

#Preview("Empty State") {
    let vm = ReceiptEditorViewModel()
    return ScrollView {
        ReceiptImageSectionView(viewModel: vm)
            .padding()
    }
}

#Preview("Attached Image") {
    let vm = ReceiptEditorViewModel()
    vm.attachSampleReceipt(.taqueriaElPastor)
    return ScrollView {
        ReceiptImageSectionView(viewModel: vm)
            .padding()
    }
}
