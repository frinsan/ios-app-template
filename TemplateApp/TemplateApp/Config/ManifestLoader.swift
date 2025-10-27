import Foundation

enum ManifestLoader {
    static func loadLocal() throws -> AppManifest {
        let url = Bundle.main.url(forResource: "app", withExtension: "json") ?? Bundle.main.url(forResource: "app", withExtension: "json", subdirectory: "Config")
        guard let url else {
            throw ManifestError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AppManifest.self, from: data)
    }
}

enum ManifestError: Error {
    case fileNotFound
}
