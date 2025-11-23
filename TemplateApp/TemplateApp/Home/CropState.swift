import CoreGraphics

struct CropState: Equatable {
    let scale: CGFloat
    let offset: CGSize
    let frameRect: CGRect
    let imageSize: CGSize
}
