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
        var onboarding: Bool
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
        var subscriptions: Bool

        enum CodingKeys: String, CodingKey {
            case settings
            case onboarding
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
            case subscriptions
        }

        init(
            settings: Bool = false,
            onboarding: Bool = false,
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
            cloudSync: Bool = false,
            subscriptions: Bool = false
        ) {
            self.settings = settings
            self.onboarding = onboarding
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
            self.subscriptions = subscriptions
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.settings = try container.decodeIfPresent(Bool.self, forKey: .settings) ?? false
            self.onboarding = try container.decodeIfPresent(Bool.self, forKey: .onboarding) ?? false
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
            self.subscriptions = try container.decodeIfPresent(Bool.self, forKey: .subscriptions) ?? false
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

        init(
            cognitoClientId: String? = nil,
            scheme: String? = nil,
            region: String? = nil,
            hostedUIDomain: String? = nil
        ) {
            self.cognitoClientId = cognitoClientId
            self.scheme = scheme
            self.region = region
            self.hostedUIDomain = hostedUIDomain
        }
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

    struct SubscriptionsConfig: Codable {
        var productIds: [String]
        var title: String?
        var subtitle: String?
        var benefits: [String]?
        var actionsTitle: String?
        var noProductsText: String?
        var checkingText: String?
        var subscribeButtonTitle: String?
        var restoreButtonTitle: String?
        var manageButtonTitle: String?
        var refreshButtonTitle: String?
        var premiumAreaTitle: String?
        var premiumAreaLockedText: String?
        var premiumAreaUnlockedText: String?

        enum CodingKeys: String, CodingKey {
            case productIds
            case title
            case subtitle
            case benefits
            case actionsTitle
            case noProductsText
            case checkingText
            case subscribeButtonTitle
            case restoreButtonTitle
            case manageButtonTitle
            case refreshButtonTitle
            case premiumAreaTitle
            case premiumAreaLockedText
            case premiumAreaUnlockedText
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.productIds = try container.decodeIfPresent([String].self, forKey: .productIds) ?? []
            self.title = try container.decodeIfPresent(String.self, forKey: .title)
            self.subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
            self.benefits = try container.decodeIfPresent([String].self, forKey: .benefits)
            self.actionsTitle = try container.decodeIfPresent(String.self, forKey: .actionsTitle)
            self.noProductsText = try container.decodeIfPresent(String.self, forKey: .noProductsText)
            self.checkingText = try container.decodeIfPresent(String.self, forKey: .checkingText)
            self.subscribeButtonTitle = try container.decodeIfPresent(String.self, forKey: .subscribeButtonTitle)
            self.restoreButtonTitle = try container.decodeIfPresent(String.self, forKey: .restoreButtonTitle)
            self.manageButtonTitle = try container.decodeIfPresent(String.self, forKey: .manageButtonTitle)
            self.refreshButtonTitle = try container.decodeIfPresent(String.self, forKey: .refreshButtonTitle)
            self.premiumAreaTitle = try container.decodeIfPresent(String.self, forKey: .premiumAreaTitle)
            self.premiumAreaLockedText = try container.decodeIfPresent(String.self, forKey: .premiumAreaLockedText)
            self.premiumAreaUnlockedText = try container.decodeIfPresent(String.self, forKey: .premiumAreaUnlockedText)
        }
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
    var subscriptions: SubscriptionsConfig?
    var activeEnvironment: Environment

    var baseURL: URL {
        switch activeEnvironment {
        case .staging: return apiBase.staging
        case .prod: return apiBase.prod
        }
    }

    private struct EnvironmentAuthConfig: Decodable {
        var staging: AuthConfig?
        var prod: AuthConfig?
    }

    enum CodingKeys: String, CodingKey {
        case appId
        case displayName
        case bundleIdSuffix
        case theme
        case features
        case apiBase
        case auth
        case legal
        case push
        case share
        case cloud
        case subscriptions
        case activeEnvironment
    }

    init(
        appId: String,
        displayName: String,
        bundleIdSuffix: String,
        theme: Theme,
        features: FeatureFlags,
        apiBase: APIConfig,
        auth: AuthConfig,
        legal: LegalConfig?,
        push: PushConfig?,
        share: ShareConfig?,
        cloud: CloudConfig?,
        subscriptions: SubscriptionsConfig?,
        activeEnvironment: Environment
    ) {
        self.appId = appId
        self.displayName = displayName
        self.bundleIdSuffix = bundleIdSuffix
        self.theme = theme
        self.features = features
        self.apiBase = apiBase
        self.auth = auth
        self.legal = legal
        self.push = push
        self.share = share
        self.cloud = cloud
        self.subscriptions = subscriptions
        self.activeEnvironment = activeEnvironment
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appId = try container.decode(String.self, forKey: .appId)
        displayName = try container.decode(String.self, forKey: .displayName)
        bundleIdSuffix = try container.decode(String.self, forKey: .bundleIdSuffix)
        theme = try container.decode(Theme.self, forKey: .theme)
        features = try container.decode(FeatureFlags.self, forKey: .features)
        apiBase = try container.decode(APIConfig.self, forKey: .apiBase)
        legal = try container.decodeIfPresent(LegalConfig.self, forKey: .legal)
        push = try container.decodeIfPresent(PushConfig.self, forKey: .push)
        share = try container.decodeIfPresent(ShareConfig.self, forKey: .share)
        cloud = try container.decodeIfPresent(CloudConfig.self, forKey: .cloud)
        subscriptions = try container.decodeIfPresent(SubscriptionsConfig.self, forKey: .subscriptions)
        activeEnvironment = try container.decode(Environment.self, forKey: .activeEnvironment)

        if let envAuth = try? container.decode(EnvironmentAuthConfig.self, forKey: .auth),
           envAuth.staging != nil || envAuth.prod != nil {
            switch activeEnvironment {
            case .staging:
                auth = envAuth.staging ?? envAuth.prod ?? AuthConfig()
            case .prod:
                auth = envAuth.prod ?? envAuth.staging ?? AuthConfig()
            }
        } else {
            auth = try container.decode(AuthConfig.self, forKey: .auth)
        }
    }

    static let placeholder: AppManifest = .init(
        appId: "com.learnandbecurious.sample",
        displayName: "Template App",
        bundleIdSuffix: "template",
        theme: .init(primaryHex: "#111111", accentHex: "#B8E986", appearance: .system),
        features: .init(
            settings: false,
            onboarding: false,
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
            cloudSync: false,
            subscriptions: false
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
        subscriptions: nil,
        activeEnvironment: .staging
    )
}
