import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Sign in")
                .font(.largeTitle.bold())

            Text("Authenticate with Apple or Google via Cognito Hosted UI.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            Button(action: { startLogin(provider: .apple) }) {
                Label(HostedUIProvider.apple.displayName, systemImage: "apple.logo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button(action: { startLogin(provider: .google) }) {
                Label(HostedUIProvider.google.displayName, systemImage: "globe")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            if isLoading {
                ProgressView()
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Login")
    }

    private func startLogin(provider: HostedUIProvider) {
        guard case .signedOut = appState.authState else { return }
        isLoading = true
        Task {
            do {
                let session = try await HostedUILoginController.signIn(provider: provider, manifest: appState.manifest)
                await MainActor.run {
                    appState.handleLoginSuccess(session)
                    isLoading = false
                }
            } catch {
                print("[Auth] Login failed: \(error)")
                await MainActor.run {
                    appState.authState = .signedOut
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AppState())
}
