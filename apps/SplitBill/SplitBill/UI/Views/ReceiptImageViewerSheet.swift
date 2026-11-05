import SwiftUI

/// Fullscreen interactive modal sheet for inspecting receipt images with pinch-to-zoom, pan, and double-tap zoom.
struct ReceiptImageViewerSheet: View {

    // MARK: - Properties & Environment

    let title: String
    private let uiImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    // MARK: - Gestures & Zoom State

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0

    // MARK: - Initializer

    init(imageData: Data, title: String) {
        self.title = title
        self.uiImage = UIImage(data: imageData)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()

                    if let uiImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(combinedGesture(viewportSize: geometry.size))
                            .onTapGesture(count: 2) {
                                toggleDoubleTapZoom()
                            }
                            .accessibilityLabel("Foto ampliada del recibo: \(title.isEmpty ? "Sin título" : title)")
                            .accessibilityHint("Usa dos dedos para hacer zoom o toca dos veces para ampliar.")
                    } else {
                        ContentUnavailableView(
                            "Imagen no disponible",
                            systemImage: "photo.badge.exclamationmark",
                            description: Text("No se pudo decodificar la imagen del recibo.")
                        )
                        .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle(title.isEmpty ? "Recibo" : title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                    .frame(minWidth: 44, minHeight: 44)
                }

                if scale > 1.05 {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("1x") {
                            resetZoomAnimated()
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("Restablecer zoom a tamaño original")
                    }
                }
            }
        }
    }

    // MARK: - Gestures

    private func combinedGesture(viewportSize: CGSize) -> some Gesture {
        let magnification = MagnifyGesture()
            .onChanged { value in
                let newScale = lastScale * value.magnification
                scale = min(max(newScale, minScale), maxScale)
            }
            .onEnded { _ in
                if scale < 1.05 {
                    resetZoomAnimated()
                } else {
                    lastScale = scale
                }
            }

        let drag = DragGesture()
            .onChanged { value in
                guard scale > 1.05 else { return }
                let maxOffsetX = max(0, (viewportSize.width * (scale - 1)) / 2)
                let maxOffsetY = max(0, (viewportSize.height * (scale - 1)) / 2)

                let proposedX = lastOffset.width + value.translation.width
                let proposedY = lastOffset.height + value.translation.height

                offset = CGSize(
                    width: min(max(proposedX, -maxOffsetX), maxOffsetX),
                    height: min(max(proposedY, -maxOffsetY), maxOffsetY)
                )
            }
            .onEnded { _ in
                guard scale > 1.05 else {
                    offset = .zero
                    lastOffset = .zero
                    return
                }
                lastOffset = offset
            }

        return SimultaneousGesture(magnification, drag)
    }

    private func toggleDoubleTapZoom() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if scale > 1.05 {
                scale = 1.0
                lastScale = 1.0
                offset = .zero
                lastOffset = .zero
            } else {
                scale = 2.5
                lastScale = 2.5
            }
        }
    }

    private func resetZoomAnimated() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            scale = 1.0
            lastScale = 1.0
            offset = .zero
            lastOffset = .zero
        }
    }
}

// MARK: - Previews

#Preview {
    let sampleData = SampleReceiptImageGenerator.generateImageData(for: .taqueriaElPastor)
    return ReceiptImageViewerSheet(imageData: sampleData, title: "Taquería El Pastor")
}
