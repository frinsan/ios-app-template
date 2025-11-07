import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isLoggingOut = false

    var body: some View {
        VStack(spacing: 24) {
            switch appState.authState {
            case .signedIn:
                profileContent()
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

    @ViewBuilder
    private func profileContent() -> some View {
        VStack(spacing: 20) {
            if let profile = appState.userProfile {
                VStack(alignment: .leading, spacing: 8) {
                    Text(profile.displayName)
                        .font(.title2.bold())
                    if let email = profile.email {
                        Label(email, systemImage: "envelope")
                            .foregroundStyle(.secondary)
                    }
                    if let environment = profile.environment {
                        Text("Environment: \(environment)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ProgressView("Loading profile…")
                    .task {
                        appState.refreshProfileIfNeeded()
                    }
            }

            if isLoggingOut {
                ProgressView("Signing out…")
            } else {
                Button("Sign out", role: .destructive, action: signOut)
                    .buttonStyle(.bordered)
            }
        }
    }

    private func signOut() {
        isLoggingOut = true
        Task {
            await appState.performLogout()
            await MainActor.run {
                isLoggingOut = false
            }
        }
    }
}

#Preview {
    AccountView()
        .environmentObject(AppState())
}
