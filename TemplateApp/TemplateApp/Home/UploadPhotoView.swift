import AVFoundation
import PhotosUI
import SwiftUI

struct UploadPhotoView: View {
    @Binding var selectedImage: UIImage?
    let onPhotoConfirmed: (UIImage) -> Void
    let onModeChange: ((Mode) -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @State private var mode: Mode = .chooseSource
    @State private var originalImage: UIImage?
    @State private var previewImage: UIImage?
    @State private var activePicker: ActivePicker?
    @State private var cameraUnavailableAlert = false
    @State private var cameraPermissionAlert = false
    @State private var photoPermissionAlert = false
    @State private var isPreparingPhoto = false

    var body: some View {
        VStack(spacing: 24) {
            switch mode {
            case .chooseSource:
                selectionView
            case .preview:
                previewView
            }
            Spacer()
        }
        .padding()
        .onAppear {
            onModeChange?(mode)
        }
        .sheet(isPresented: binding(for: .library)) {
            PhotoLibraryPickerView { image in
                handleImageSelection(image)
            }
        }
        .fullScreenCover(isPresented: binding(for: .camera)) {
            CameraCaptureView { image in
                handleImageSelection(image)
            }
        }
        .alert("Camera Unavailable", isPresented: $cameraUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device cannot access the camera. Try uploading from your photo library instead.")
        }
        .alert("Camera Access Needed", isPresented: $cameraPermissionAlert) {
            Button("Open Settings") { openSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow camera access to take a new photo.")
        }
        .alert("Photo Access Needed", isPresented: $photoPermissionAlert) {
            Button("Open Settings") { openSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow photo library access to pick an existing image.")
        }
        .overlay {
            if isPreparingPhoto {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Preparing photo…")
                            .font(.callout)
                            .foregroundStyle(Color.white)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black.opacity(0.65))
                    )
                }
            }
        }
    }

    private var selectionView: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Start New Photo")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.primaryText)
                Text("Take a new picture or upload from your library.")
                    .font(.callout)
                    .foregroundStyle(Color.secondaryText)
            }

            actionButton(
                title: "Take Photo",
                subtitle: "Use your device camera",
                icon: "camera.fill"
            ) {
                handleCameraSelection()
            }

            actionButton(
                title: "Upload from Library",
                subtitle: "Pick an existing photo",
                icon: "photo.on.rectangle"
            ) {
                handleLibrarySelection()
            }
        }
    }

    private var previewView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Review Photo")
                    .font(.title.bold())
                    .foregroundStyle(Color.primaryText)

                Text("Use a white or light plain background. No shadows.")
                    .font(.callout)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
            }

            GeometryReader { proxy in
                let frameRect = PreviewLayout.frame(in: proxy.size, safeAreaInsets: proxy.safeAreaInsets)
                ZStack {
                    Color.black

                    if let image = previewImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: frameRect.width, height: frameRect.height)
                            .clipped()
                    } else {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Loading photo…")
                                .font(.caption)
                                .foregroundStyle(Color.secondaryText)
                        }
                        .frame(width: frameRect.width, height: frameRect.height)
                    }
                }
                .frame(width: frameRect.width, height: frameRect.height)
                .position(x: frameRect.midX, y: frameRect.midY)
            }
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .frame(maxWidth: .infinity)

            HStack(spacing: 16) {
                Button {
                    originalImage = nil
                    previewImage = nil
                    setMode(.chooseSource)
                } label: {
                    Text("Retake")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.primaryAccent)

                Button {
                    if let image = previewImage {
                        isPreparingPhoto = true
                        DispatchQueue.global(qos: .userInitiated).async {
                            let finalImage = image
                            DispatchQueue.main.async {
                                selectedImage = finalImage
                                onPhotoConfirmed(finalImage)
                                isPreparingPhoto = false
                            }
                        }
                    }
                } label: {
                    Text("Use Photo")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.primaryAccent)
                .disabled(previewImage == nil)
            }
        }
    }

    private func actionButton(
        title: String,
        subtitle: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.15))
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(buttonTextColor)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(buttonTextColor.opacity(0.8))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(buttonTextColor.opacity(0.8))
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.primaryAccent)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func handleImageSelection(_ image: UIImage?) {
        guard let image else { return }
        isPreparingPhoto = true
        DispatchQueue.global(qos: .userInitiated).async {
            let rendered = image.renderedPreviewImage()
            DispatchQueue.main.async {
                originalImage = image
                previewImage = rendered
                setMode(.preview)
                isPreparingPhoto = false
            }
        }
    }

    private func handleCameraSelection() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            cameraUnavailableAlert = true
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            activePicker = .camera
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        activePicker = .camera
                    } else {
                        cameraPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            cameraPermissionAlert = true
        @unknown default:
            cameraPermissionAlert = true
        }
    }

    private func handleLibrarySelection() {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited:
            activePicker = .library
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    if status == .authorized || status == .limited {
                        activePicker = .library
                    } else {
                        photoPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            photoPermissionAlert = true
        @unknown default:
            photoPermissionAlert = true
        }
    }

    private func setMode(_ newMode: Mode) {
        mode = newMode
        onModeChange?(newMode)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

extension UploadPhotoView {
    enum Mode {
        case chooseSource
        case preview
    }

    enum ActivePicker: Identifiable {
        case camera
        case library

        var id: Int {
            switch self {
            case .camera: return 0
            case .library: return 1
            }
        }
    }

    private func binding(for picker: ActivePicker) -> Binding<Bool> {
        Binding(
            get: { activePicker == picker },
            set: { newValue in
                if newValue {
                    activePicker = picker
                } else if activePicker == picker {
                    activePicker = nil
                }
            }
        )
    }

    private var buttonTextColor: Color {
        if colorScheme == .dark {
            return Color(red: 30 / 255, green: 41 / 255, blue: 59 / 255)
        }
        return Color.primaryText
    }
}

private extension UIImage {
    func renderedPreviewImage(targetSize: CGSize = CGSize(width: 1200, height: 1600)) -> UIImage {
        let normalized = normalizedImage()
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { ctx in
            ctx.cgContext.setFillColor(UIColor.black.cgColor)
            ctx.cgContext.fill(CGRect(origin: .zero, size: targetSize))

            let targetRatio = targetSize.width / targetSize.height
            let imageRatio = normalized.size.width / normalized.size.height
            var drawRect = CGRect(origin: .zero, size: targetSize)

            if imageRatio > targetRatio {
                let newHeight = targetSize.height
                let newWidth = newHeight * imageRatio
                drawRect.size = CGSize(width: newWidth, height: newHeight)
                drawRect.origin.x = (targetSize.width - newWidth) / 2
            } else {
                let newWidth = targetSize.width
                let newHeight = newWidth / imageRatio
                drawRect.size = CGSize(width: newWidth, height: newHeight)
                drawRect.origin.y = (targetSize.height - newHeight) / 2
            }

            normalized.draw(in: drawRect)
        }
    }

    func normalizedImage() -> UIImage {
        guard imageOrientation != .up else { return self }
        return UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

#Preview {
    UploadPhotoView(
        selectedImage: .constant(nil),
        onPhotoConfirmed: { _ in },
        onModeChange: nil
    )
    .environmentObject(AppState())
}
