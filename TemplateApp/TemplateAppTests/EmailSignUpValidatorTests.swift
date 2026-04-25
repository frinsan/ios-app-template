import XCTest
@testable import TemplateApp

final class EmailSignUpValidatorTests: XCTestCase {
    func testEmailMustContainAtSymbolAndDot() {
        XCTAssertFalse(EmailSignUpValidator.isValidEmail("userexample.com"))
        XCTAssertFalse(EmailSignUpValidator.isValidEmail("user@examplecom"))
        XCTAssertTrue(EmailSignUpValidator.isValidEmail("user@example.com"))
    }

    func testFormRequiresMatchingPasswords() {
        XCTAssertFalse(
            EmailSignUpValidator.isFormValid(
                email: "user@example.com",
                password: "Password1234",
                confirmPassword: "Password0000"
            )
        )

        XCTAssertTrue(
            EmailSignUpValidator.isFormValid(
                email: "user@example.com",
                password: "Password1234",
                confirmPassword: "Password1234"
            )
        )
    }

    func testManifestMenuDefaultsPreserveFeatureBasedSidebarBehavior() throws {
        let manifest = try decodeManifest(
            features: """
            {
              "settings": true,
              "onboarding": false,
              "login": true,
              "push": false,
              "share": false,
              "pushDeepLink": false,
              "imageCapture": true,
              "loadingOverlay": true,
              "errorBanner": true,
              "ratePrompt": false,
              "aiPlayground": true,
              "cloudSync": false,
              "subscriptions": true
            }
            """,
            activeEnvironment: "staging"
        )

        XCTAssertTrue(manifest.showsMenuItem(.settings))
        XCTAssertTrue(manifest.showsMenuItem(.imageCapture))
        XCTAssertTrue(manifest.showsMenuItem(.aiPlayground))
        XCTAssertTrue(manifest.showsMenuItem(.subscriptions))
        XCTAssertTrue(manifest.isSettingsDeveloperInfoVisible)
    }

    func testManifestMenuCanHideCapabilitySidebarItems() throws {
        let manifest = try decodeManifest(
            features: """
            {
              "settings": true,
              "onboarding": false,
              "login": true,
              "push": false,
              "share": false,
              "pushDeepLink": false,
              "imageCapture": true,
              "loadingOverlay": true,
              "errorBanner": true,
              "ratePrompt": false,
              "aiPlayground": true,
              "cloudSync": false,
              "subscriptions": true
            }
            """,
            extraTopLevelFields: """
            ,
              "menu": {
                "settings": true,
                "imageCapture": false,
                "aiPlayground": false,
                "subscriptions": false
              },
              "settings": {
                "showDeveloperInfo": false
              }
            """,
            activeEnvironment: "staging"
        )

        XCTAssertTrue(manifest.showsMenuItem(.settings))
        XCTAssertFalse(manifest.showsMenuItem(.imageCapture))
        XCTAssertFalse(manifest.showsMenuItem(.aiPlayground))
        XCTAssertFalse(manifest.showsMenuItem(.subscriptions))
        XCTAssertFalse(manifest.isSettingsDeveloperInfoVisible)
    }

    func testManifestExplicitSettingsDeveloperInfoOverridesProdFallback() throws {
        let manifest = try decodeManifest(
            features: """
            {
              "settings": true,
              "onboarding": false,
              "login": true,
              "push": false,
              "share": false,
              "pushDeepLink": false,
              "imageCapture": false,
              "loadingOverlay": true,
              "errorBanner": true,
              "ratePrompt": false,
              "aiPlayground": false,
              "cloudSync": false,
              "subscriptions": false
            }
            """,
            extraTopLevelFields: """
            ,
              "settings": {
                "showDeveloperInfo": true
              }
            """,
            activeEnvironment: "prod"
        )

        XCTAssertTrue(manifest.isSettingsDeveloperInfoVisible)
    }

    private func decodeManifest(
        features: String,
        extraTopLevelFields: String = "",
        activeEnvironment: String
    ) throws -> AppManifest {
        let json = """
        {
          "appId": "com.learnandbecurious.tests",
          "displayName": "Test App",
          "bundleIdSuffix": "tests",
          "theme": {
            "primary": "#111111",
            "accent": "#B8E986",
            "appearance": "system"
          },
          "features": \(features),
          "apiBase": {
            "staging": "https://staging.example.com",
            "prod": "https://prod.example.com"
          },
          "auth": {
            "cognitoClientId": "client",
            "scheme": "testapp",
            "region": "us-west-2",
            "hostedUIDomain": "auth.example.com"
          },
          "activeEnvironment": "\(activeEnvironment)"
          \(extraTopLevelFields)
        }
        """

        return try JSONDecoder().decode(AppManifest.self, from: Data(json.utf8))
    }
}
