import SwiftUI
import UIKit

/// A `UIViewControllerRepresentable` wrapping `UIImagePickerController` for taking receipt photos.
///
/// Automatically handles device camera availability, normalizes captured images via `ReceiptImageProcessor`,
/// and dismisses cleanly upon capture or cancellation.
struct CameraCaptureView: UIViewControllerRepresentable {

    @Environment(\.dismiss) private var dismiss
    let onImageCaptured: (Data) -> Void

    /// Indicates whether physical camera hardware is available on the current device.
    static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        if Self.isCameraAvailable {
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: CameraCaptureView

        init(_ parent: CameraCaptureView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            defer { parent.dismiss() }
            guard let image = info[.originalImage] as? UIImage else { return }
            if let processed = ReceiptImageProcessor.process(image) {
                parent.onImageCaptured(processed)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
