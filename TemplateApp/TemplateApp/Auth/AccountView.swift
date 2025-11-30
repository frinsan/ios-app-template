import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var pushManager = PushManager.shared
    @State private var isLoggingOut = false
    @State private var isDeleting = false
    @State private var showDeleteConfirm = false
    @State private var deleteConfirmationText = ""
    @State private var deleteError: String?
    @State private var isSendingTestPush = false
    @State private var pushTestStatus: String?

    var body: some View {
        VStack(spacing: 24) {
        switch appState.authState {
        case .signedIn:
            profileContent()
        default:
            Text("You are not signed in yet.")
                .foregroundStyle(Color.secondaryText)
            NavigationLink(destination: LoginView()) {
                Text("Go to Login")
            }
            .themedCTA(accentColor: accentColor, prefersSoftDarkText: true)
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
                accentColor: accentColor,
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
                    Text(resolvedDisplayName(for: profile))
                        .font(.title2.bold())
                    if let email = profile.email ?? sessionEmail {
                        Label(email, systemImage: "envelope")
                            .foregroundStyle(Color.secondaryText)
                    }
                    if let provider = profile.providerLabel {
                        Label("Signed in with \(provider)", systemImage: "person.crop.circle.badge.checkmark")
                            .foregroundStyle(Color.secondaryText)
                    }
                    if let verification = profile.emailVerificationLabel {
                        Label(verification, systemImage: "checkmark.seal")
                            .foregroundStyle(Color.secondaryText)
                    }
                    if let lastLogin = formattedDate(profile.lastLoginAt) {
                        Label("Last login: \(lastLogin)", systemImage: "clock")
                            .foregroundStyle(Color.secondaryText)
                    }
                    if let environment = profile.environment?.lowercased(), environment != "prod" {
                        Text("Environment: \(environment)")
                            .font(.footnote)
                            .foregroundStyle(Color.secondaryText)
                    }
                    if appState.manifest.features.push {
                        pushSection()
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
                .buttonStyle(ConsistentButtonStyle(accentColor: accentColor, prefersSoftDarkText: true))
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
                .buttonStyle(ConsistentButtonStyle(accentColor: accentColor, prefersSoftDarkText: true))
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
        Color.primaryAccent
    }

    var sessionEmail: String? {
        if case let .signedIn(session) = appState.authState {
            return session.user.email
        }
        return nil
    }

    func resolvedDisplayName(for profile: UserProfile) -> String {
        let displayName = profile.displayName
        guard displayName == profile.userId else {
            return displayName
        }

        if let email = profile.email ?? sessionEmail {
            return email
        }

        return "Email hidden"
    }

    func formattedDate(_ isoString: String?) -> String? {
        guard let isoString else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) ?? ISO8601DateFormatter().date(from: isoString) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .short
            return display.string(from: date)
        }
        return nil
    }

    func pushSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notifications")
                .font(.headline)
            Label(authorizationText, systemImage: "bell.badge")
                .foregroundStyle(Color.secondaryText)
            if let token = pushManager.deviceToken {
                Text("Device token: \(token)")
                    .font(.footnote.monospaced())
                    .foregroundStyle(Color.secondaryText)
            }
            if let registerStatus = appState.pushRegisterStatus {
                Text(registerStatus)
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
            }
            if let error = pushManager.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            if let status = pushTestStatus {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
            }
            Button("Request notifications") {
                Task {
                    await pushManager.requestAuthorizationAndRegister()
                }
            }
            .buttonStyle(ConsistentButtonStyle(accentColor: accentColor, prefersSoftDarkText: true))
            if case let .signedIn(session) = appState.authState {
                Button(isSendingTestPush ? "Sending…" : "Send test push") {
                    Task {
                        await sendTestPush(session: session)
                    }
                }
                .disabled(isSendingTestPush)
                .buttonStyle(ConsistentButtonStyle(accentColor: accentColor, prefersSoftDarkText: true))
            }
        }
        .padding()
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear {
            pushManager.refreshAuthorizationStatus()
        }
    }

    var authorizationText: String {
        switch pushManager.authorizationStatus {
        case .notDetermined: return "Not requested"
        case .denied: return "Denied"
        case .authorized, .provisional, .ephemeral: return "Allowed"
        @unknown default: return "Unknown"
        }
    }

    func sendTestPush(session: AuthSession) async {
        guard appState.manifest.features.push else { return }
        isSendingTestPush = true
        pushTestStatus = nil
        let service = PushService(manifest: appState.manifest)
        do {
            try await service.sendTest(session: session)
            await MainActor.run {
                pushTestStatus = "Test push requested."
                isSendingTestPush = false
            }
        } catch let apiError as APIError {
            await MainActor.run {
                switch apiError {
                case let .responseError(message, _):
                    pushTestStatus = message ?? "Failed to send test push."
                    NSLog("[Push] Test push error: \(message ?? "unknown")")
                }
                isSendingTestPush = false
            }
        } catch {
            await MainActor.run {
                pushTestStatus = "Failed to send test push."
                isSendingTestPush = false
            }
            NSLog("[Push] Test push error: \(error.localizedDescription)")
        }
    }
}

private struct DeleteAccountSheet: View {
    @Binding var confirmationText: String
    @Binding var errorMessage: String?
    let accentColor: Color
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Deleting your account removes your profile, saved preferences, and any related data from this app. This action is permanent and cannot be undone. Type DELETE to confirm.")
                    .font(.callout)
                    .foregroundStyle(Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

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
                    .buttonStyle(ConsistentButtonStyle(accentColor: accentColor, prefersSoftDarkText: true))
                    .opacity(confirmationText == "DELETE" ? 1 : 0.65)

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
