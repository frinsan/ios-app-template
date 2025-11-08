import Foundation

struct AppManifest: Codable {
    struct Theme: Codable {
        var primaryHex: String
        var accentHex: String
        var appearance: Appearance

        enum CodingKeys: String, CodingKey {
            case primaryHex = "primary"
            case accentHex = "accent"
            case appearance
        }

        enum Appearance: String, Codable {
            case light
            case dark
            case system
        }
    }

    struct FeatureFlags: Codable {
        var login: Bool
        var feedback: Bool
    }

    struct APIConfig: Codable {
        var staging: URL
        var prod: URL
    }

    struct AuthConfig: Codable {
        var cognitoClientId: String?
        var scheme: String?
        var region: String?
        var hostedUIDomain: String?
    }

    enum Environment: String, Codable {
        case staging
        case prod
    }

    var appId: String
    var displayName: String
    var bundleIdSuffix: String
    var theme: Theme
    var features: FeatureFlags
    var apiBase: APIConfig
    var auth: AuthConfig
    var activeEnvironment: Environment

    var baseURL: URL {
        switch activeEnvironment {
        case .staging: return apiBase.staging
        case .prod: return apiBase.prod
        }
    }

    static let placeholder: AppManifest = .init(
        appId: "com.learnandbecurious.sample",
        displayName: "Template App",
        bundleIdSuffix: "template",
        theme: .init(primaryHex: "#111111", accentHex: "#B8E986", appearance: .system),
        features: .init(login: true, feedback: false),
        apiBase: .init(
            staging: URL(string: "https://staging.api.example.com")!,
            prod: URL(string: "https://api.example.com")!
        ),
        auth: .init(cognitoClientId: nil, scheme: nil, region: nil, hostedUIDomain: nil),
        activeEnvironment: .staging
    )
}
