import SwiftUI
import UIKit
import Combine

@main
struct TemplateAppApp: App {
    @UIApplicationDelegateAdaptor(PushAppDelegate.self) var pushDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            AppEntryView()
                .environmentObject(appState)
                .tint(.primaryAccent)
        }
    }
}

final class AppState: ObservableObject {
    @Published var manifest: AppManifest = .placeholder
    @Published var authState: AuthState = .signedOut
    @Published var userProfile: UserProfile?
    @Published var latestLoginSuccessID: UUID?
    @Published var shouldShowWelcome: Bool = true
    @Published var pushToken: String?
    @Published var pushRegisterStatus: String?

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadManifest()
        PushManager.shared.configure()
        observePushTokens()
        restoreSession()
    }

    func loadManifest() {
        do {
            manifest = try ManifestLoader.loadLocal()
        } catch {
            print("[Manifest] Failed to load: \(error)")
        }
    }

    private func restoreSession() {
        if let session = AuthSessionStorage.shared.load(), !session.isExpired {
            authState = .signedIn(session)
            shouldShowWelcome = false
            Task {
                await bootstrapAndFetchProfile(forceBootstrap: false)
                await registerPushTokenIfNeeded()
            }
        } else {
            shouldShowWelcome = true
        }
    }

    func handleLoginSuccess(_ session: AuthSession) {
        do {
            try AuthSessionStorage.shared.store(session)
        } catch {
            print("[Auth] Failed to persist session: \(error)")
        }

        authState = .signedIn(session)
        shouldShowWelcome = false
        latestLoginSuccessID = UUID()
        Task {
            await bootstrapAndFetchProfile(forceBootstrap: true)
            await registerPushTokenIfNeeded()
        }
    }

    func refreshProfileIfNeeded() {
        guard userProfile == nil else { return }
        Task {
            await bootstrapAndFetchProfile(forceBootstrap: false)
        }
    }

    func performLogout() async {
        if case let .signedIn(session) = authState {
            if manifest.features.push, let token = pushToken {
                let service = PushService(manifest: manifest)
                try? await service.unregister(token: token, session: session)
            }
            do {
                try await HostedUILoginController.logout(manifest: manifest)
            } catch {
                print("[Auth] Logout failed: \(error)")
            }
        }

        await MainActor.run {
            AuthSessionStorage.shared.clear()
            userProfile = nil
            authState = .signedOut
            shouldShowWelcome = true
            pushRegisterStatus = nil
        }
    }

    func dismissWelcome() {
        shouldShowWelcome = false
    }

    private func observePushTokens() {
        PushManager.shared.$deviceToken
            .receive(on: DispatchQueue.main)
            .sink { [weak self] token in
                self?.pushToken = token
                Task {
                    await self?.registerPushTokenIfNeeded()
                }
            }
            .store(in: &cancellables)
    }

    private func bootstrapAndFetchProfile(forceBootstrap: Bool) async {
        guard case let .signedIn(session) = authState else { return }
        let service = UserProfileService(manifest: manifest)
        do {
            if forceBootstrap {
                _ = try await service.bootstrapProfile(session: session)
            }
            let profile = try await service.fetchProfile(session: session)
            await MainActor.run {
                self.userProfile = profile
            }
        } catch {
            print("[Profile] Failed to sync: \(error)")
        }
    }

    private func registerPushTokenIfNeeded() async {
        guard manifest.features.push else { return }
        guard let token = pushToken else { return }
        guard case let .signedIn(session) = authState else { return }
        let service = PushService(manifest: manifest)
        do {
            try await service.register(token: token, session: session)
            await MainActor.run {
                self.pushRegisterStatus = "Push token registered."
            }
        } catch {
            NSLog("[Push] Failed to register token: \(error.localizedDescription)")
            await MainActor.run {
                self.pushRegisterStatus = "Register failed: \(error.localizedDescription)"
            }
        }
    }
}

enum AuthState {
    case signedOut
    case signingIn
    case signedIn(AuthSession)
}

struct AppEntryView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.shouldShowWelcome, case .signedOut = appState.authState {
                WelcomeView {
                    appState.dismissWelcome()
                }
            } else {
                RootContainerView()
            }
        }
    }
}

extension AuthState: Equatable {
    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.signedOut, .signedOut), (.signingIn, .signingIn):
            return true
        case let (.signedIn(a), .signedIn(b)):
            let leftIdentifier = a.user.subject.isEmpty ? a.idToken : a.user.subject
            let rightIdentifier = b.user.subject.isEmpty ? b.idToken : b.user.subject
            return leftIdentifier == rightIdentifier
        default:
            return false
        }
    }
}

final class PushAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushManager.shared.handleDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushManager.shared.handleRegistrationError(error)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        PushManager.shared.handleRemoteNotification(userInfo)
        completionHandler(.noData)
    }
}
