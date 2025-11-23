import SwiftUI

struct EditAdjustView: View {
    let image: UIImage
    let preset: PhotoPreset
    let onBack: () -> Void
    let onNext: (CropState) -> Void

    @State private var userScale: CGFloat = 1
    @State private var steadyScale: CGFloat = 1
    @State private var userOffset: CGSize = .zero
    @State private var steadyOffset: CGSize = .zero
    @State private var frameRect: CGRect = .zero
    @State private var baseScale: CGFloat = 1

    private var imageSize: CGSize {
        image.size
    }

    var body: some View {
        VStack(spacing: 20) {
            GeometryReader { proxy in
                let bounds = proxy.size
                let targetFrame = Self.frameRect(in: bounds, aspectRatio: preset.aspectRatio)
                let computedBaseScale = Self.baseScale(for: imageSize, frame: targetFrame)

                Color.clear
                    .background(
                        ZStack {
                            Color.black.opacity(0.6)
                            cropLayer(frame: targetFrame, baseScale: computedBaseScale, canvasSize: bounds)
                        }
                        .onAppear {
                            updateCachedValues(frame: targetFrame, baseScale: computedBaseScale)
                        }
                        .onChange(of: targetFrame) { _, newValue in
                            updateCachedValues(frame: newValue, baseScale: computedBaseScale)
                        }
                    )
            }
            .frame(maxWidth: .infinity)

            Text("Pinch to zoom and drag to align the face inside the circle.")
                .font(.callout)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 16) {
                Button("Back") { onBack() }
                    .buttonStyle(.bordered)
                    .tint(.primaryAccent)

                Button("Next") {
                    let state = CropState(
                        scale: baseScale * userScale,
                        offset: userOffset,
                        frameRect: frameRect,
                        imageSize: imageSize
                    )
                    onNext(state)
                }
                .buttonStyle(.borderedProminent)
                .tint(.primaryAccent)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color.appBackground.ignoresSafeArea())
    }

    @ViewBuilder
    private func cropLayer(frame: CGRect, baseScale: CGFloat, canvasSize: CGSize) -> some View {
        let actualScale = baseScale * userScale
        let imageWidth = imageSize.width * actualScale
        let imageHeight = imageSize.height * actualScale

        let drag = DragGesture()
            .onChanged { value in
                let raw = CGSize(
                    width: steadyOffset.width + value.translation.width,
                    height: steadyOffset.height + value.translation.height
                )
                userOffset = clampOffset(raw, frameSize: frame.size, actualScale: actualScale)
            }
            .onEnded { _ in
                steadyOffset = userOffset
            }

        let magnification = MagnificationGesture()
            .onChanged { value in
                let newScale = clampScale(steadyScale * value)
                userScale = newScale
                let newActualScale = baseScale * newScale
                userOffset = clampOffset(steadyOffset, frameSize: frame.size, actualScale: newActualScale)
            }
            .onEnded { _ in
                steadyScale = userScale
                steadyOffset = clampOffset(steadyOffset, frameSize: frame.size, actualScale: baseScale * userScale)
                userOffset = steadyOffset
            }

        let combinedGesture = drag.simultaneously(with: magnification)

        ZStack {
            Rectangle()
                .fill(Color.white)
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)

            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: imageWidth, height: imageHeight)
                .offset(userOffset)
                .gesture(combinedGesture)

            overlay(frame: frame, canvasSize: canvasSize)
        }
    }

    private func overlay(frame: CGRect, canvasSize: CGSize) -> some View {
        let bounds = CGRect(origin: .zero, size: canvasSize)

        return ZStack {
            Path { path in
                path.addRect(bounds)
                path.addRoundedRect(in: frame, cornerSize: CGSize(width: 32, height: 32))
            }
            .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))

            if abs(preset.aspectRatio - 1.0) < 0.01 {
                Image("guide_silhouette")
                    .resizable()
                    .scaledToFit()
                    .frame(width: frame.width, height: frame.height, alignment: .top)
                    .position(x: frame.midX, y: frame.midY)
                    .allowsHitTesting(false)
            } else {
                Image("guide_silhouette_rect")
                    .resizable()
                    .scaledToFit()
                    .frame(width: frame.width, height: frame.height, alignment: .top)
                    .position(x: frame.midX, y: frame.midY)
                    .allowsHitTesting(false)
            }

            RoundedRectangle(cornerRadius: 32)
                .stroke(Color.primaryAccent, lineWidth: 2)
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)

            Path { path in
                path.move(to: CGPoint(x: frame.minX + 16, y: frame.midY - frame.height * 0.1))
                path.addLine(to: CGPoint(x: frame.maxX - 16, y: frame.midY - frame.height * 0.1))
            }
            .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [10]))
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }

    private func updateCachedValues(frame: CGRect, baseScale: CGFloat) {
        if abs(self.baseScale - baseScale) > 0.0001 {
            self.baseScale = baseScale
            let actualScale = baseScale * userScale
            let clamped = clampOffset(userOffset, frameSize: frame.size, actualScale: actualScale)
            userOffset = clamped
            steadyOffset = clamped
        }
        if frameRect != frame {
            frameRect = frame
        }
    }

    private func clampScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, 0.5), 3)
    }

    private func clampOffset(_ offset: CGSize, frameSize: CGSize, actualScale: CGFloat) -> CGSize {
        let imageWidth = imageSize.width * actualScale
        let imageHeight = imageSize.height * actualScale
        let extraHorizontal = frameSize.width * 1.5
        let extraVertical = frameSize.height * 1.5
        let horizontalLimit = max((imageWidth - frameSize.width) / 2, 0) + extraHorizontal
        let verticalLimit = max((imageHeight - frameSize.height) / 2, 0) + extraVertical

        let clampedWidth = min(max(offset.width, -horizontalLimit), horizontalLimit)
        let clampedHeight = min(max(offset.height, -verticalLimit), verticalLimit)
        return CGSize(width: clampedWidth, height: clampedHeight)
    }

    private static func frameRect(in bounds: CGSize, aspectRatio: Double) -> CGRect {
        let widthLimit = bounds.width * 0.9
        let heightLimit = bounds.height * 0.8
        var frameWidth = widthLimit
        var frameHeight = frameWidth / aspectRatio

        if frameHeight > heightLimit {
            frameHeight = heightLimit
            frameWidth = frameHeight * aspectRatio
        }

        if frameWidth > widthLimit {
            frameWidth = widthLimit
            frameHeight = frameWidth / aspectRatio
        }

        let originX = (bounds.width - frameWidth) / 2
        let originY = (bounds.height - frameHeight) / 2
        return CGRect(x: originX, y: originY, width: frameWidth, height: frameHeight)
    }

    private static func baseScale(for imageSize: CGSize, frame: CGRect) -> CGFloat {
        let widthScale = frame.width / imageSize.width
        let heightScale = frame.height / imageSize.height
        return max(widthScale, heightScale)
    }
}

#Preview {
    let presets = PresetLibraryLoader.loadPresets()
    let preset = presets.first ?? PhotoPreset(
        id: "preview",
        country: "Preview",
        label: "Preview",
        docType: .passport,
        widthMM: 35,
        heightMM: 45,
        dpi: 300,
        notes: nil
    )
    return EditAdjustView(
        image: UIImage(named: "Preview") ?? UIImage(systemName: "person.crop.square")!,
        preset: preset,
        onBack: {},
        onNext: { _ in }
    )
}
