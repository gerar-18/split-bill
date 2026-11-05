import PhotosUI
import SwiftUI

/// Section view for attaching, previewing, and managing physical or digital receipt tickets.
/// Supports camera capture (on physical devices), system photo library selection, and sample presets for simulator/testing.
struct ReceiptImageSectionView: View {

    // MARK: - Bindings & Local State

    @Bindable var viewModel: ReceiptEditorViewModel
    @State private var isViewerPresented = false
    @State private var isCameraPresented = false
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
            }
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

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Foto adjunta del recibo. Toca para ver en pantalla completa con zoom.")

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

        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            Label("Elegir de galería", systemImage: "photo")
        }

        Menu {
            ForEach(SampleReceiptPreset.allCases) { preset in
                Button(preset.displayName) {
                    viewModel.attachSampleReceipt(preset)
                }
            }
        } label: {
            Label("Usar ticket de muestra", systemImage: "sparkles")
        }

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
                }
            } catch {
                viewModel.validationMessage = "Error al cargar la foto seleccionada."
            }
            selectedPhotoItem = nil
            isProcessingPhoto = false
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
