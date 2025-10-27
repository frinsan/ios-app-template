import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var appState: AppState

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
                Button("Sign out", role: .destructive, action: signOut)
                    .buttonStyle(.bordered)
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
        AuthSessionStorage.shared.clear()
        appState.authState = .signedOut
    }
}

#Preview {
    AccountView()
        .environmentObject(AppState())
}
