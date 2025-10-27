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
        }
    }
}

enum AuthState {
    case signedOut
    case signingIn
    case signedIn(AuthSession)
}
