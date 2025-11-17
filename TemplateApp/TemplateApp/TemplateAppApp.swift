import SwiftUI

@main
struct TemplateAppApp: App {
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

    init() {
        loadManifest()
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
        }
    }

    func refreshProfileIfNeeded() {
        guard userProfile == nil else { return }
        Task {
            await bootstrapAndFetchProfile(forceBootstrap: false)
        }
    }

    func performLogout() async {
        if case .signedIn = authState {
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
        }
    }

    func dismissWelcome() {
        shouldShowWelcome = false
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
