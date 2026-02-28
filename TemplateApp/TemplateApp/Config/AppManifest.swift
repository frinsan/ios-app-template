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
        var settings: Bool
        var login: Bool
        var feedback: Bool
        var push: Bool
        var share: Bool
        var pushDeepLink: Bool
        var imageCapture: Bool
        var loadingOverlay: Bool
        var errorBanner: Bool
        var ratePrompt: Bool
        var aiPlayground: Bool
        var cloudSync: Bool

        enum CodingKeys: String, CodingKey {
            case settings
            case login
            case feedback
            case push
            case share
            case pushDeepLink
            case imageCapture
            case loadingOverlay
            case errorBanner
            case ratePrompt
            case aiPlayground
            case cloudSync
        }

        init(
            settings: Bool = false,
            login: Bool = true,
            feedback: Bool = false,
            push: Bool = false,
            share: Bool = false,
            pushDeepLink: Bool = false,
            imageCapture: Bool = false,
            loadingOverlay: Bool = true,
            errorBanner: Bool = true,
            ratePrompt: Bool = false,
            aiPlayground: Bool = false,
            cloudSync: Bool = false
        ) {
            self.settings = settings
            self.login = login
            self.feedback = feedback
            self.push = push
            self.share = share
            self.pushDeepLink = pushDeepLink
            self.imageCapture = imageCapture
            self.loadingOverlay = loadingOverlay
            self.errorBanner = errorBanner
            self.ratePrompt = ratePrompt
            self.aiPlayground = aiPlayground
            self.cloudSync = cloudSync
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.settings = try container.decodeIfPresent(Bool.self, forKey: .settings) ?? false
            self.login = try container.decodeIfPresent(Bool.self, forKey: .login) ?? true
            self.feedback = try container.decodeIfPresent(Bool.self, forKey: .feedback) ?? false
            self.push = try container.decodeIfPresent(Bool.self, forKey: .push) ?? false
            self.share = try container.decodeIfPresent(Bool.self, forKey: .share) ?? false
            self.pushDeepLink = try container.decodeIfPresent(Bool.self, forKey: .pushDeepLink) ?? false
            self.imageCapture = try container.decodeIfPresent(Bool.self, forKey: .imageCapture) ?? false
            self.loadingOverlay = try container.decodeIfPresent(Bool.self, forKey: .loadingOverlay) ?? true
            self.errorBanner = try container.decodeIfPresent(Bool.self, forKey: .errorBanner) ?? true
            self.ratePrompt = try container.decodeIfPresent(Bool.self, forKey: .ratePrompt) ?? false
            self.aiPlayground = try container.decodeIfPresent(Bool.self, forKey: .aiPlayground) ?? false
            self.cloudSync = try container.decodeIfPresent(Bool.self, forKey: .cloudSync) ?? false
        }
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

    struct LegalConfig: Codable {
        var privacyUrl: URL?
        var termsUrl: URL?

        enum CodingKeys: String, CodingKey {
            case privacyUrl
            case termsUrl
        }
    }

    struct ShareConfig: Codable {
        var text: String?
        var url: URL?
        var icon: String?
    }

    struct PushConfig: Codable {
        var categories: [String]?
    }

    struct CloudConfig: Codable {
        var containerId: String?
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
    var legal: LegalConfig?
    var push: PushConfig?
    var share: ShareConfig?
    var cloud: CloudConfig?
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
        features: .init(
            settings: false,
            login: true,
            feedback: false,
            push: false,
            share: false,
            pushDeepLink: false,
            imageCapture: false,
            loadingOverlay: true,
            errorBanner: true,
            ratePrompt: false,
            aiPlayground: false,
            cloudSync: false
        ),
        apiBase: .init(
            staging: URL(string: "https://staging.api.example.com")!,
            prod: URL(string: "https://api.example.com")!
        ),
        auth: .init(cognitoClientId: nil, scheme: nil, region: nil, hostedUIDomain: nil),
        legal: nil,
        push: nil,
        share: nil,
        cloud: nil,
        activeEnvironment: .staging
    )
}
