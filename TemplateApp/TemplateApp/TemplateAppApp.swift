import SwiftUI

@main
struct TemplateAppApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootContainerView()
                .environmentObject(appState)
        }
    }
}

final class AppState: ObservableObject {
    @Published var manifest: AppManifest = .placeholder
    @Published var authState: AuthState = .signedOut
    @Published var userProfile: UserProfile?
    @Published var latestLoginSuccessID: UUID?
    @Published var profileCompletionPrompt: ProfileCompletionPrompt?

    private var pendingProfileOverrides: ProfileOverrides?

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
            Task {
                await bootstrapAndFetchProfile(forceBootstrap: false)
            }
        }
    }

    func handleLoginSuccess(_ session: AuthSession) {
        do {
            try AuthSessionStorage.shared.store(session)
        } catch {
            print("[Auth] Failed to persist session: \(error)")
        }

        authState = .signedIn(session)
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

    func setPendingProfileOverrides(email: String?, username: String?) {
        let trimmedEmail = email?.trimmedOrNil
        let trimmedUsername = username?.trimmedOrNil
        pendingProfileOverrides = ProfileOverrides(email: trimmedEmail, username: trimmedUsername)
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
            profileCompletionPrompt = nil
            pendingProfileOverrides = nil
        }
    }

    func completeProfile(email: String, username: String) async throws {
        guard case let .signedIn(session) = authState else { return }
        let overrides = ProfileOverrides(email: email.trimmedOrNil, username: username.trimmedOrNil)
        let service = UserProfileService(manifest: manifest)
        _ = try await service.bootstrapProfile(session: session, overrides: overrides)
        await bootstrapAndFetchProfile(forceBootstrap: false)
    }

    private func bootstrapAndFetchProfile(forceBootstrap: Bool) async {
        guard case let .signedIn(session) = authState else { return }
        let service = UserProfileService(manifest: manifest)
        do {
            if forceBootstrap || pendingProfileOverrides != nil {
                _ = try await service.bootstrapProfile(session: session, overrides: pendingProfileOverrides)
                await MainActor.run {
                    pendingProfileOverrides = nil
                }
            }
            let profile = try await service.fetchProfile(session: session)
            await MainActor.run {
                self.userProfile = profile
                self.updateProfileCompletionPrompt(profile: profile, session: session)
            }
        } catch {
            print("[Profile] Failed to sync: \(error)")
        }
    }

    private func updateProfileCompletionPrompt(profile: UserProfile, session: AuthSession) {
        let needsUsername = profile.username?.isEmpty ?? true
        let needsEmail = profile.email?.isEmpty ?? true
        if needsUsername || needsEmail {
            profileCompletionPrompt = ProfileCompletionPrompt(
                missingEmail: needsEmail,
                missingUsername: needsUsername,
                currentEmail: profile.email ?? session.user.email ?? "",
                currentUsername: profile.username ?? ""
            )
        } else {
            profileCompletionPrompt = nil
        }
    }
}

enum AuthState {
    case signedOut
    case signingIn
    case signedIn(AuthSession)
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
