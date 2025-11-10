import SwiftUI
import Combine

struct ForgotPasswordRequestView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var pendingReset: PendingPasswordReset?
    @FocusState private var focusedField: ForgotPasswordRequestField?

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
            } footer: {
                Text("We'll send a verification code to reset your password.")
                    .font(.footnote)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(action: submit) {
                    if isSubmitting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Send reset code").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(ConsistentButtonStyle(accentColor: accentColor))
                .disabled(isSubmitting)
            }
        }
        .navigationTitle("Reset password")
        .lightModeTextColor()
        .navigationDestination(item: $pendingReset) { pending in
            ForgotPasswordConfirmView(pending: pending, newPasswordHint: "Choose a new password")
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .onChange(of: appState.latestLoginSuccessID) { _ in
            dismiss()
        }
    }

    private func submit() {
        guard !email.isEmpty else {
            errorMessage = "Enter the email associated with your account."
            return
        }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let service = EmailAuthService(manifest: appState.manifest)
                let result = try await service.startPasswordReset(email: email)
                await MainActor.run {
                    pendingReset = PendingPasswordReset(
                        email: email,
                        message: result.message,
                        deliveryDescription: result.deliveryDescription
                    )
                    isSubmitting = false
                }
                AnalyticsClient.shared.track(.emailPasswordResetRequested, properties: [
                    "emailDomain": emailDomain(from: email)
                ])
            } catch let apiError as APIError {
                await MainActor.run {
                    switch apiError {
                    case let .responseError(message, _):
                        errorMessage = message ?? "Unable to send reset code."
                    }
                    isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Unexpected error. Please try again."
                    isSubmitting = false
                }
            }
        }
    }

    private var accentColor: Color {
        Color(hex: appState.manifest.theme.accentHex)
    }

    private func emailDomain(from email: String) -> String {
        email.split(separator: "@").last.map(String.init) ?? "unknown"
    }
}

struct ForgotPasswordConfirmView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let pending: PendingPasswordReset
    let newPasswordHint: String
    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var isNewPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @State private var isResending = false
    @State private var resendStatus: String?
    @State private var resendCooldownRemaining = 0
    @AppStorage("ForgotPasswordResendCooldownUntil") private var forgotResendCooldownUntil: Double = 0
    private let resendCooldownSeconds = 60
    private let resendTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @FocusState private var focusedField: ForgotPasswordConfirmField?

    var body: some View {
        Form {
            Section(footer: Text(pending.message).font(.footnote)) {
                Text("We sent a code to \(pending.deliveryDescription). Enter it below along with your new password.")
            }

            Section {
                TextField("6-digit code", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($focusedField, equals: .code)

                passwordInput(
                    title: newPasswordHint,
                    text: $newPassword,
                    isVisible: $isNewPasswordVisible,
                    field: .newPassword
                )

                passwordInput(
                    title: "Confirm new password",
                    text: $confirmPassword,
                    isVisible: $isConfirmPasswordVisible,
                    field: .confirmPassword
                )
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Resend code") {
                    Task { await resendCode() }
                }
                .disabled(isResending || resendCooldownRemaining > 0)
                VStack(alignment: .leading, spacing: 4) {
                    if resendCooldownRemaining > 0 {
                        Text("You can resend in \(resendCooldownRemaining)s.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let resendStatus {
                        Text(resendStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button(action: submit) {
                    if isSubmitting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Update password").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(ConsistentButtonStyle(accentColor: accentColor))
                .disabled(isSubmitting)
            }
        }
        .navigationTitle("Enter code")
        .lightModeTextColor()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .onChange(of: appState.latestLoginSuccessID) { _ in
            dismiss()
        }
        .onAppear {
            updateResendCooldown()
        }
        .onReceive(resendTimer) { _ in
            tickResendCooldown()
        }
    }

    private func submit() {
        guard !code.isEmpty else {
            errorMessage = "Enter the verification code."
            return
        }
        guard !newPassword.isEmpty else {
            errorMessage = "Enter a new password."
            return
        }
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let service = EmailAuthService(manifest: appState.manifest)
                try await service.confirmPasswordReset(
                    email: pending.email,
                    code: code,
                    newPassword: newPassword
                )
                let session = try await service.login(email: pending.email, password: newPassword)
                await MainActor.run {
                    appState.handleLoginSuccess(session)
                    isSubmitting = false
                }
                AnalyticsClient.shared.track(.emailPasswordResetConfirmed, properties: [
                    "emailDomain": emailDomain(from: pending.email)
                ])
            } catch let apiError as APIError {
                await MainActor.run {
                    switch apiError {
                    case let .responseError(message, _):
                        errorMessage = message ?? "Unable to update password."
                    }
                    isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Unexpected error. Please try again."
                    isSubmitting = false
                }
            }
        }
    }

    private func resendCode() async {
        guard !isResending else { return }
        isResending = true
        do {
            let service = EmailAuthService(manifest: appState.manifest)
            let result = try await service.startPasswordReset(email: pending.email)
            await MainActor.run {
                resendStatus = "Code resent to \(result.deliveryDescription)."
                isResending = false
                forgotResendCooldownUntil = Date().addingTimeInterval(Double(resendCooldownSeconds)).timeIntervalSince1970
                updateResendCooldown()
            }
            AnalyticsClient.shared.track(.emailPasswordResetRequested, properties: [
                "emailDomain": emailDomain(from: pending.email),
                "context": "resend"
            ])
        } catch let apiError as APIError {
            await MainActor.run {
                switch apiError {
                case let .responseError(message, _):
                    resendStatus = message ?? "Unable to resend verification code."
                }
                isResending = false
            }
        } catch {
            await MainActor.run {
                resendStatus = "Unexpected error. Please try again."
                isResending = false
            }
        }
    }

    private func passwordInput(
        title: String,
        text: Binding<String>,
        isVisible: Binding<Bool>,
        field: ForgotPasswordConfirmField
    ) -> some View {
        HStack {
            Group {
                if isVisible.wrappedValue {
                    TextField(title, text: text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField(title, text: text)
                }
            }
            .focused($focusedField, equals: field)

            Button(action: { isVisible.wrappedValue.toggle() }) {
                Image(systemName: isVisible.wrappedValue ? "eye" : "eye.slash")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var accentColor: Color {
        Color(hex: appState.manifest.theme.accentHex)
    }

    private func emailDomain(from email: String) -> String {
        email.split(separator: "@").last.map(String.init) ?? "unknown"
    }

    private func updateResendCooldown() {
        let remaining = Int(forgotResendCooldownUntil - Date().timeIntervalSince1970)
        resendCooldownRemaining = max(0, remaining)
    }

    private func tickResendCooldown() {
        guard resendCooldownRemaining > 0 else { return }
        resendCooldownRemaining -= 1
        if resendCooldownRemaining <= 0 {
            resendCooldownRemaining = 0
            forgotResendCooldownUntil = 0
        }
    }
}

struct PendingPasswordReset: Identifiable, Hashable {
    let id = UUID()
    let email: String
    let message: String
    let deliveryDescription: String
}

private enum ForgotPasswordRequestField: Hashable {
    case email
}

private enum ForgotPasswordConfirmField: Hashable {
    case code
    case newPassword
    case confirmPassword
}
