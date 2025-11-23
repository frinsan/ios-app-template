import Foundation

struct PhotoPreset: Identifiable, Hashable, Decodable {
    enum DocType: String, Decodable {
        case visa
        case passport
    }

    let id: String
    let country: String
    let label: String
    let docType: DocType
    let widthMM: Double
    let heightMM: Double
    let dpi: Int
    let notes: String?

    var aspectRatio: Double {
        guard heightMM != 0 else { return 1 }
        return widthMM / heightMM
    }
}
