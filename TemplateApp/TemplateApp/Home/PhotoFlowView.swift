import SwiftUI
import UIKit
import ImageIO
import UniformTypeIdentifiers
import Photos

struct PhotoFlowView: View {
    @Environment(\.dismiss) private var dismiss
    private let presets: [PhotoPreset]
    @State private var step: FlowStep
    @State private var uploadStepTitle: String = "New Photo"
    @State private var sourceImage: UIImage?
    @State private var selectedPreset: PhotoPreset?
    @State private var cropState: CropState?

    init(
        initialImage: UIImage? = nil,
        startStep: FlowStep = .uploadPhoto,
        presets: [PhotoPreset] = PresetLibraryLoader.loadPresets()
    ) {
        self.presets = presets
        _sourceImage = State(initialValue: initialImage)
        _step = State(initialValue: initialImage == nil ? .uploadPhoto : startStep)
    }

    var body: some View {
        Group {
            switch step {
            case .uploadPhoto:
                UploadPhotoView(selectedImage: $sourceImage) { image in
                    sourceImage = image
                    step = .chooseFormat
                } onModeChange: { mode in
                    switch mode {
                    case .chooseSource:
                        uploadStepTitle = "New Photo"
                    case .preview:
                        uploadStepTitle = "Review"
                    }
                }
            case .chooseFormat:
                ChooseFormatView(
                    presets: presets,
                    onSelectPreset: { preset in
                        selectedPreset = preset
                        step = .editAndAdjust
                    }
                )
            case .editAndAdjust:
                if let image = sourceImage, let preset = selectedPreset {
                    EditAdjustView(
                        image: image,
                        preset: preset,
                        onBack: { step = .chooseFormat },
                        onNext: { state in
                            cropState = state
                            step = .exportAndSave
                        }
                    )
                } else {
                    placeholderView(
                        title: "Missing Data",
                        message: "Select a photo and format before editing."
                    )
                }
            case .exportAndSave:
                if let image = sourceImage, let preset = selectedPreset, let state = cropState {
                    ExportAndSaveView(
                        originalImage: image,
                        preset: preset,
                        cropState: state,
                        onBack: { step = .editAndAdjust },
                        onDone: handleFlowCompletion
                    )
                } else {
                    placeholderView(
                        title: "Export & Save",
                        message: "Missing data required for exporting. Please restart the flow."
                    )
                }
            }
        }
        .navigationTitle(stepTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: goBack) {
                    Image(systemName: "chevron.backward")
                }
                .accessibilityLabel("Back")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Close") { dismiss() }
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
    }

    private func placeholderView(title: String, message: String) -> some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "photo.badge.arrow.down")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundStyle(Color.primaryAccent)
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(Color.primaryText)
            Text(message)
                .font(.callout)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
            Button("Back to Home") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(.primaryAccent)
        }
        .padding()
    }

    private func handleFlowCompletion() {
        resetFlow()
        dismiss()
    }

    private func resetFlow() {
        step = .uploadPhoto
        sourceImage = nil
        selectedPreset = nil
        cropState = nil
    }

    private func goBack() {
        switch step {
        case .uploadPhoto:
            dismiss()
        case .chooseFormat:
            step = .uploadPhoto
        case .editAndAdjust:
            step = .chooseFormat
        case .exportAndSave:
            step = .editAndAdjust
        }
    }
}

extension PhotoFlowView {
    enum FlowStep {
        case uploadPhoto
        case chooseFormat
        case editAndAdjust
        case exportAndSave
    }

    private var stepTitle: String {
        switch step {
        case .uploadPhoto: return uploadStepTitle
        case .chooseFormat: return "Format"
        case .editAndAdjust: return "Edit"
        case .exportAndSave: return "Export"
        }
    }
}

#Preview {
    NavigationStack {
        PhotoFlowView()
    }
}

struct ExportAndSaveView: View {
    let originalImage: UIImage
    let preset: PhotoPreset
    let cropState: CropState
    let onBack: () -> Void
    let onDone: () -> Void

    @State private var exportResult: PhotoExportResult?
    @State private var isSharing = false
    @State private var saveAlert: SaveAlert?
    @State private var saveSettingsAlert = false
    private let photoSaver = PhotoSaver()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                previewSection
                detailsSection
                actionsSection
            }
            .padding()
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .background(Color.appBackground.ignoresSafeArea())
        .onAppear(perform: generateExportIfNeeded)
        .sheet(isPresented: $isSharing) {
            if let result = exportResult {
                ShareSheet(items: [result.data])
            }
        }
        .alert(item: $saveAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
        .alert("Could Not Save Photo", isPresented: $saveSettingsAlert) {
            Button("Open Settings") { openSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow photo access in Settings to save your export.")
        }
    }

    private var previewSection: some View {
        Group {
            if let result = exportResult {
                Image(uiImage: result.image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.2), radius: 18, y: 12)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Preparing export…")
                        .font(.footnote)
                        .foregroundStyle(Color.secondaryText)
                }
                .frame(height: 300)
            }
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(preset.label)
                .font(.title2.bold())
                .foregroundStyle(Color.primaryText)
            Text("\(Int(preset.widthMM)) x \(Int(preset.heightMM)) mm · \(preset.dpi) dpi")
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
            if let result = exportResult {
                Text("\(result.widthPx) × \(result.heightPx) px")
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionsSection: some View {
        VStack(spacing: 16) {
            Button {
                guard let data = exportResult?.data else { return }
                photoSaver.save(data: data) { outcome in
                    switch outcome {
                    case .success:
                        saveAlert = SaveAlert(title: "Saved", message: "Photo saved to your library.")
                    case .failure:
                        saveSettingsAlert = true
                    }
                }
            } label: {
                Label("Save to Photos", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.primaryAccent)
            .disabled(exportResult == nil)

            Button {
                isSharing = true
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.primaryAccent)
            .disabled(exportResult == nil)

            Button {
                onDone()
            } label: {
                Label("Complete", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.primaryAccent)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
    }

    private func generateExportIfNeeded() {
        guard exportResult == nil else { return }
        exportResult = PhotoExporter.render(
            originalImage: originalImage,
            cropState: cropState,
            preset: preset,
            dpi: preset.dpi
        )
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

private struct SaveAlert: Identifiable {
    let title: String
    let message: String

    var id: String { title + message }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct PhotoExportResult {
    let image: UIImage
    let data: Data
    let widthPx: Int
    let heightPx: Int
    let dpi: Int
}

private enum PhotoExporter {
    static func render(originalImage: UIImage, cropState: CropState, preset: PhotoPreset, dpi: Int) -> PhotoExportResult {
        let sourceImage = originalImage.normalized()
        let (widthPx, heightPx): (Int, Int) = {
            let isUSPassportOrVisa =
                preset.id == "us_passport" ||
                preset.id == "us-passport" ||
                preset.id == "us_visa" ||
                preset.label == "United States – Passport" ||
                preset.label == "United States – Visa" ||
                preset.label == "US Passport" ||
                preset.label == "US Visa"

            if isUSPassportOrVisa {
                let side = max(Int(round(Double(preset.dpi) * 2.0)), 1)
                return (side, side)
            }

            let widthInches = preset.widthMM / 25.4
            let heightInches = preset.heightMM / 25.4
            let widthPx = max(Int(round(widthInches * Double(preset.dpi))), 1)
            let heightPx = max(Int(round(heightInches * Double(preset.dpi))), 1)
            return (widthPx, heightPx)
        }()

        let size = CGSize(width: CGFloat(widthPx), height: CGFloat(heightPx))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderedImage = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

                let renderScale = CGFloat(widthPx) / cropState.frameRect.width
                let context = ctx.cgContext
                context.translateBy(x: size.width / 2, y: size.height / 2)
                context.scaleBy(x: renderScale, y: renderScale)
                context.translateBy(x: cropState.offset.width, y: cropState.offset.height)
                context.scaleBy(x: cropState.scale, y: cropState.scale)
                context.translateBy(x: -cropState.imageSize.width / 2, y: -cropState.imageSize.height / 2)
                context.scaleBy(x: 1, y: -1)
                context.translateBy(x: 0, y: -cropState.imageSize.height)
                context.interpolationQuality = .high

                let drawRect = CGRect(origin: .zero, size: cropState.imageSize)
                if let cgImage = sourceImage.cgImage {
                    context.draw(cgImage, in: drawRect)
                } else {
                    sourceImage.draw(in: drawRect)
                }
            }

        guard let cgImage = renderedImage.cgImage else {
            return PhotoExportResult(image: renderedImage, data: Data(), widthPx: widthPx, heightPx: heightPx, dpi: dpi)
        }

        let data = NSMutableData()
        let type = UTType.jpeg.identifier as CFString
        guard let destination = CGImageDestinationCreateWithData(data, type, 1, nil) else {
            return PhotoExportResult(image: renderedImage, data: Data(), widthPx: widthPx, heightPx: heightPx, dpi: dpi)
        }

        let metadata: [CFString: Any] = [
            kCGImagePropertyDPIWidth: dpi,
            kCGImagePropertyDPIHeight: dpi,
            kCGImagePropertyJFIFDictionary: [
                kCGImagePropertyJFIFDensityUnit: 1,
                kCGImagePropertyJFIFXDensity: dpi,
                kCGImagePropertyJFIFYDensity: dpi
            ],
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFXResolution: dpi,
                kCGImagePropertyTIFFYResolution: dpi,
                kCGImagePropertyTIFFResolutionUnit: 2
            ]
        ]
        CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)
        guard CGImageDestinationFinalize(destination),
              let finalImage = UIImage(data: data as Data, scale: 1) else {
            return PhotoExportResult(image: renderedImage, data: data as Data, widthPx: widthPx, heightPx: heightPx, dpi: dpi)
        }

        return PhotoExportResult(image: finalImage, data: data as Data, widthPx: widthPx, heightPx: heightPx, dpi: dpi)
    }
}

    private extension UIImage {
        func normalized() -> UIImage {
            guard imageOrientation != .up else { return self }
            return UIGraphicsImageRenderer(size: size).image { _ in
                draw(in: CGRect(origin: .zero, size: size))
            }
        }
    }

private final class PhotoSaver {
    func save(data: Data, completion: @escaping (Result<Void, Error>) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "PhotoSaver", code: 1, userInfo: [NSLocalizedDescriptionKey: "Photos access denied."])))
                }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                let options = PHAssetResourceCreationOptions()
                options.originalFilename = "VisaPhoto.jpg"
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: options)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(.failure(error))
                    } else if success {
                        completion(.success(()))
                    } else {
                        completion(.failure(NSError(domain: "PhotoSaver", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown Photos error."])))
                    }
                }
            }
        }
    }
}
