import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isLoggingOut = false
    @State private var isDeleting = false
    @State private var showDeleteConfirm = false
    @State private var deleteConfirmationText = ""
    @State private var deleteError: String?

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
            .themedCTA(accentColor: accentColor)
        }
            Spacer()
        }
        .padding()
        .navigationTitle("Account")
        .lightModeTextColor()
        .sheet(isPresented: $showDeleteConfirm) {
            DeleteAccountSheet(
                confirmationText: $deleteConfirmationText,
                errorMessage: $deleteError,
                onConfirm: confirmDeletion,
                onCancel: { showDeleteConfirm = false }
            )
        }
        .alert("Unable to delete account", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK", role: .cancel) { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
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
                Button(role: .destructive, action: signOut) {
                    Text("Sign out")
                }
                .buttonStyle(ConsistentButtonStyle(accentColor: accentColor))
            }

            if isDeleting {
                ProgressView("Deleting account…")
            } else {
                Button(role: .destructive, action: {
                    deleteConfirmationText = ""
                    deleteError = nil
                    showDeleteConfirm = true
                }) {
                    Text("Delete account")
                }
                .buttonStyle(ConsistentButtonStyle(accentColor: accentColor))
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

    private func confirmDeletion() {
        guard deleteConfirmationText == "DELETE" else { return }
        showDeleteConfirm = false
        performDeleteAccount()
    }

    private func performDeleteAccount() {
        guard case let .signedIn(session) = appState.authState else { return }
        isDeleting = true
        Task {
            do {
                let service = UserProfileService(manifest: appState.manifest)
                try await service.deleteAccount(session: session)
                await appState.performLogout()
                await MainActor.run {
                    isDeleting = false
                    AnalyticsClient.shared.track(.accountDeleted, properties: ["context": "account"])
                }
            } catch let apiError as APIError {
                await MainActor.run {
                    switch apiError {
                    case let .responseError(message, _):
                        deleteError = message ?? "Unable to delete account."
                    }
                    isDeleting = false
                }
            } catch {
                await MainActor.run {
                    deleteError = "Unexpected error. Please try again."
                    isDeleting = false
                }
            }
        }
    }
}

#Preview {
    AccountView()
        .environmentObject(AppState())
}

private extension AccountView {
    var accentColor: Color {
        Color(hex: appState.manifest.theme.accentHex)
    }
}

private struct DeleteAccountSheet: View {
    @Binding var confirmationText: String
    @Binding var errorMessage: String?
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("This cannot be undone")
                    .font(.headline)
                Text("Type DELETE to permanently remove your account and data.")
                TextField("Type DELETE", text: $confirmationText)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button("Delete account", role: .destructive, action: onConfirm)
                    .disabled(confirmationText != "DELETE")
                    .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding()
            .navigationTitle("Confirm deletion")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}
