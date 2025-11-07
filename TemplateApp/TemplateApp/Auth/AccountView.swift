import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isLoggingOut = false

    var body: some View {
        VStack(spacing: 24) {
            switch appState.authState {
            case .signedIn(let session):
                VStack(spacing: 12) {
                    Text(session.user.email ?? session.user.subject)
                        .font(.title2.bold())
                    if let given = session.user.givenName {
                        Text("Welcome back, \(given)!")
                            .foregroundStyle(.secondary)
                    }
                }
                if isLoggingOut {
                    ProgressView("Signing out…")
                } else {
                    Button("Sign out", role: .destructive, action: signOut)
                        .buttonStyle(.bordered)
                }
            default:
                Text("You are not signed in yet.")
                    .foregroundStyle(.secondary)
                NavigationLink(destination: LoginView()) {
                    Text("Go to Login")
                }
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Account")
    }

    private func signOut() {
        guard case .signedIn = appState.authState else {
            return
        }
        isLoggingOut = true
        Task {
            do {
                try await HostedUILoginController.logout(manifest: appState.manifest)
            } catch {
                // Swallow errors; we'll still clear local session
            }
            AuthSessionStorage.shared.clear()
            await MainActor.run {
                appState.authState = .signedOut
                isLoggingOut = false
            }
        }
    }
}

#Preview {
    AccountView()
        .environmentObject(AppState())
}
