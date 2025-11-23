import SwiftUI

struct GuideSilhouetteOverlay: View {
    let frame: CGRect
    var isEditMode: Bool = false

    private var targetHeight: CGFloat {
        frame.height * 0.78
    }

    private var centerY: CGFloat {
        (frame.height / 2) - (frame.height * 0.08)
    }

    var body: some View {
        Group {
            if isEditMode {
                let insetY = frame.height * 0.05
                let insetX = frame.width * 0.05
                let width = frame.width - (insetX * 2)
                let height = frame.height - (insetY * 2)

                Image("guide_silhouette")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width, height: height)
                    .position(x: frame.width / 2, y: frame.height / 2)
                    .foregroundStyle(Color.white.opacity(0.3))
            } else {
                Image("guide_silhouette")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(height: targetHeight)
                    .position(x: frame.width / 2, y: centerY)
                    .foregroundStyle(Color.white.opacity(0.3))
            }
        }
        .frame(width: frame.width, height: frame.height)
        .allowsHitTesting(false)
    }
}

enum PreviewLayout {
    static func frame(in size: CGSize, safeAreaInsets: EdgeInsets) -> CGRect {
        let availableWidth = size.width - (safeAreaInsets.leading + safeAreaInsets.trailing)
        let availableHeight = size.height - (safeAreaInsets.top + safeAreaInsets.bottom)
        let aspectRatio: CGFloat = 4.0 / 3.0
        var width = availableWidth
        var height = width * aspectRatio

        if height > availableHeight {
            height = availableHeight
            width = height / aspectRatio
        }

        let originX = (size.width - width) / 2
        let originY = safeAreaInsets.top + (availableHeight - height) / 2
        return CGRect(x: originX, y: originY, width: width, height: height)
    }
}
