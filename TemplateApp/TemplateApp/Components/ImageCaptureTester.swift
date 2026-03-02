import AVFoundation
import SwiftUI
import UIKit

struct ImageCaptureTester: View {
    @EnvironmentObject private var cloudSyncManager: CloudSyncManager

    @State private var note: String = ""
    @State private var selectedImage: UIImage?

    @State private var showLibraryPicker = false
    @State private var showCameraCapture = false
    @State private var showImageSourceDialog = false
    @State private var showCameraUnavailableAlert = false
    @State private var showCameraAccessAlert = false
    @State private var localErrorMessage: String?
    @State private var viewerPresentation: ViewerImagePresentation?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Optional note", text: $note)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(false)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.appBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.dividerColor, lineWidth: 1)
                )

            imageArea
            actionButtons

            if let localErrorMessage, !localErrorMessage.isEmpty {
                Text(localErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.red)
            }

        }
        .sheet(isPresented: $showLibraryPicker) {
            PhotoLibraryPickerView { image in
                applyPickedImage(image)
            }
        }
        .fullScreenCover(isPresented: $showCameraCapture) {
            CameraCaptureView { image in
                applyPickedImage(image)
            }
        }
        .alert("Camera unavailable", isPresented: $showCameraUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Camera is not available on this device. Please use Upload photo.")
        }
        .confirmationDialog(
            "Choose image source",
            isPresented: $showImageSourceDialog,
            titleVisibility: .visible
        ) {
            Button("Upload photo") {
                showLibraryPicker = true
            }
            Button("Take photo") {
                presentCamera()
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(item: $viewerPresentation) { presentation in
            ImageCaptureFullscreenViewer(image: presentation.image)
        }
        .alert("Camera access required", isPresented: $showCameraAccessAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        } message: {
            Text("Allow camera access in iOS Settings to take a photo.")
        }
    }

    @ViewBuilder
    private var imageArea: some View {
        if let selectedImage {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    viewerPresentation = ViewerImagePresentation(image: selectedImage)
                } label: {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 180, maxHeight: 320)
                        .background(Color.appBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.dividerColor, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Text("Tap image to view full screen")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            }
        } else {
            Button {
                showImageSourceDialog = true
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(Color.primaryAccent)
                    Text("Upload photo / Take photo")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .background(Color.appBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [8, 5]))
                        .foregroundStyle(Color.dividerColor)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            if selectedImage != nil {
                HStack(spacing: 10) {
                    Button {
                        showImageSourceDialog = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.rotate")
                                .font(.system(size: 14, weight: .medium))
                            Text("Retake photo")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundStyle(Color.primaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.appBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.dividerColor, lineWidth: 0.7)
                                )
                        )
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        selectedImage = nil
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .medium))
                            Text("Remove photo")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }

            HStack(spacing: 8) {
                Button("Save image record") {
                    saveRecord()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.primaryAccent)
                .disabled(selectedImage == nil)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func saveRecord() {
        guard let selectedImage else {
            localErrorMessage = "Please select an image before saving."
            return
        }
        localErrorMessage = nil
        cloudSyncManager.createImageRecord(note: note, image: selectedImage)
        resetComposer()
    }

    private func resetComposer() {
        note = ""
        selectedImage = nil
        localErrorMessage = nil
    }

    private func applyPickedImage(_ image: UIImage?) {
        guard let image else {
            // User canceled picker/camera; keep current state without showing an error.
            return
        }
        selectedImage = image
        localErrorMessage = nil
    }

    private func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showCameraUnavailableAlert = true
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCameraCapture = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showCameraCapture = true
                    } else {
                        showCameraAccessAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showCameraAccessAlert = true
        @unknown default:
            showCameraAccessAlert = true
        }
    }

}

private struct ViewerImagePresentation: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct ImageCaptureFullscreenViewer: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ZoomableImageView(image: image)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 20)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.white)
                }
            }
        }
    }
}

private struct ZoomableImageView: View {
    let image: UIImage
    @State private var zoomScale: CGFloat = 1
    @State private var lastZoomScale: CGFloat = 1

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(zoomScale)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let delta = value / lastZoomScale
                        lastZoomScale = value
                        zoomScale = min(max(zoomScale * delta, 1), 5)
                    }
                    .onEnded { _ in
                        lastZoomScale = 1
                        if zoomScale < 1 { zoomScale = 1 }
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    zoomScale = zoomScale > 1.1 ? 1 : 2
                }
            }
    }
}
