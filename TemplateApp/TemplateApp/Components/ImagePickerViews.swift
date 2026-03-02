import PhotosUI
import SwiftUI

struct PhotoLibraryPickerView: UIViewControllerRepresentable {
    var onImagePicked: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onImagePicked: (UIImage?) -> Void

        init(onImagePicked: @escaping (UIImage?) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                onImagePicked(nil)
                return
            }

            provider.loadObject(ofClass: UIImage.self) { object, _ in
                let image = object as? UIImage
                DispatchQueue.main.async {
                    self.onImagePicked(image)
                }
            }
        }
    }
}

struct CameraPickerView: UIViewControllerRepresentable {
    var onImagePicked: (UIImage?) -> Void
    @Binding var showOverlay: Bool

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .front
        picker.modalPresentationStyle = .fullScreen
        picker.showsCameraControls = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, showOverlay: $showOverlay)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onImagePicked: (UIImage?) -> Void
        @Binding private var showOverlay: Bool

        init(onImagePicked: @escaping (UIImage?) -> Void, showOverlay: Binding<Bool>) {
            self.onImagePicked = onImagePicked
            _showOverlay = showOverlay
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.presentingViewController?.dismiss(animated: true) {
                DispatchQueue.main.async {
                    self.showOverlay = true
                }
                self.onImagePicked(nil)
            }
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            picker.presentingViewController?.dismiss(animated: true) {
                DispatchQueue.main.async {
                    self.showOverlay = true
                }
                self.onImagePicked(image)
            }
        }

        func navigationController(
            _ navigationController: UINavigationController,
            willShow viewController: UIViewController,
            animated: Bool
        ) {
            let shouldShowOverlay = navigationController.viewControllers.count <= 1
            DispatchQueue.main.async {
                self.showOverlay = shouldShowOverlay
            }
        }
    }
}

struct CameraCaptureView: View {
    var onImagePicked: (UIImage?) -> Void

    @State private var showOverlay = true

    var body: some View {
        CameraPickerView(onImagePicked: onImagePicked, showOverlay: $showOverlay)
            .ignoresSafeArea()
        .background(Color.overlayScrim.ignoresSafeArea())
    }
}
