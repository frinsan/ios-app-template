import Foundation

struct PresetLibrary: Decodable {
    let presets: [PhotoPreset]
}

enum PresetLibraryLoader {
    static func loadPresets() -> [PhotoPreset] {
        guard let url = Bundle.main.url(forResource: "presets_library", withExtension: "json") else {
            print("[Presets] presets_library.json not found in bundle")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let library = try JSONDecoder().decode(PresetLibrary.self, from: data)
            return library.presets
        } catch {
            print("[Presets] Failed to decode presets: \(error)")
            return []
        }
    }
}
