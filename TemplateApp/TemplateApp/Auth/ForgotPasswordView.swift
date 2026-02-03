import SwiftUI
import Combine

struct ForgotPasswordRequestView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var deliveryDescription: String?
    @State private var infoMessage: String?
    @State private var errorMessage: String?
    @State private var codeErrorMessage: String?
    @State private var resendStatusMessage: String?
    @State private var isSendingCode = false
    @State private var isSubmitting = false
    @State private var isCodeSectionEnabled = false
    @State private var isNewPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @State private var resendCooldownRemaining = 0
    @AppStorage("ForgotPasswordResendCooldownUntil") private var forgotResendCooldownUntil: Double = 0
    private let resendCooldownSeconds = 60
    private let resendTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @FocusState private var focusedField: ForgotPasswordField?

    var body: some View {
        Form {
            emailSection

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            actionsSection

            verificationSection

            Section {
                Button(action: submitNewPassword) {
                    if isSubmitting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Update password").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(ConsistentButtonStyle(accentColor: accentColor, prefersSoftDarkText: true))
                .disabled(!isCodeSectionEnabled || isSubmitting)
            }
        }
        .navigationTitle("Reset password")
        .lightModeTextColor()
        .onChange(of: appState.latestLoginSuccessID) { _, _ in
            dismiss()
        }
        .onAppear {
            updateResendCooldown()
        }
        .onReceive(resendTimer) { _ in
            tickResendCooldown()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
    }

    private var accentColor: Color {
        Color.primaryAccent
    }

    private var isEmailValid: Bool {
        EmailSignUpValidator.isValidEmail(email.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var newPasswordValidationMessage: String? {
        guard !newPassword.isEmpty else { return nil }
        return newPassword.count >= 12 ? nil : "Password must be at least 12 characters."
    }

    private var confirmPasswordValidationMessage: String? {
        guard !confirmPassword.isEmpty else { return nil }
        guard !newPassword.isEmpty else { return nil }
        return newPassword == confirmPassword ? nil : "Passwords must match."
    }

    @ViewBuilder
    private var emailSection: some View {
        Section {
            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .disabled(isCodeSectionEnabled)
                .focused($focusedField, equals: .email)

            if isCodeSectionEnabled {
                Button("Change email") {
                    resetFlow()
                }
                .font(.footnote)
            }
        } footer: {
            if let deliveryDescription, isCodeSectionEnabled {
                Text("We sent a code to \(deliveryDescription).").font(.footnote)
            } else {
                Text("We'll email you a verification code to reset your password.")
                    .font(.footnote)
            }
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        Section {
            Button(action: sendResetCode) {
                if isSendingCode {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text(isCodeSectionEnabled ? "Resend code" : "Get reset code")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(ConsistentButtonStyle(accentColor: accentColor, prefersSoftDarkText: true))
            .disabled(!isEmailValid || isSendingCode || resendCooldownRemaining > 0)

            if resendCooldownRemaining > 0 {
                Text("You can resend in \(resendCooldownRemaining)s.")
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
            }
            if let infoMessage {
                Text(infoMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
            }
            if let resendStatusMessage {
                Text(resendStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
            }
        }
    }

    @ViewBuilder
    private var verificationSection: some View {
        Section("Verification Code") {
            TextField("6-digit code", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .disabled(!isCodeSectionEnabled)
                .focused($focusedField, equals: .code)

            passwordInput(
                title: "New password",
                text: $newPassword,
                isVisible: $isNewPasswordVisible,
                field: .newPassword
            )
            .disabled(!isCodeSectionEnabled)
            if let message = newPasswordValidationMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            passwordInput(
                title: "Confirm new password",
                text: $confirmPassword,
                isVisible: $isConfirmPasswordVisible,
                field: .confirmPassword
            )
            .disabled(!isCodeSectionEnabled)
            if let message = confirmPasswordValidationMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if let codeErrorMessage {
                Text(codeErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private func sendResetCode() {
        guard isEmailValid else {
            errorMessage = "Enter the email associated with your account."
            return
        }
        guard resendCooldownRemaining == 0 else { return }
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = nil
        codeErrorMessage = nil
        infoMessage = nil
        resendStatusMessage = nil
        isSendingCode = true

        Task {
            do {
                let service = EmailAuthService(manifest: appState.manifest)
                let result = try await service.startPasswordReset(email: normalizedEmail)
                await MainActor.run {
                    email = normalizedEmail
                    deliveryDescription = result.deliveryDescriptionString
                    isCodeSectionEnabled = true
                    infoMessage = result.message
                    startResendCooldown()
                    focusedField = .code
                    isSendingCode = false
                }
                AnalyticsClient.shared.track(.emailPasswordResetRequested, properties: [
                    "emailDomain": emailDomain(from: normalizedEmail)
                ])
            } catch let apiError as APIError {
                await MainActor.run {
                    handleResetError(apiError, email: normalizedEmail)
                    isSendingCode = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Unexpected error. Please try again."
                    isSendingCode = false
                }
            }
        }
    }

    private func handleResetError(_ apiError: APIError, email: String) {
        if apiError.code == "RESET_RATE_LIMITED" {
            infoMessage = apiError.message ?? "We already sent you a code. Check your inbox."
            Task { await fetchResetStatus(email: email) }
        } else {
            errorMessage = apiError.message ?? "Unable to send reset code."
        }
    }

    private func fetchResetStatus(email: String) async {
        do {
            let service = EmailAuthService(manifest: appState.manifest)
            let status = try await service.passwordResetStatus(email: email)
            await MainActor.run {
                if status.status == .pending, let retry = status.retryAfterSeconds {
                    forgotResendCooldownUntil = Date().addingTimeInterval(Double(retry)).timeIntervalSince1970
                    updateResendCooldown()
                    isCodeSectionEnabled = true
                    focusedField = .code
                }
            }
        } catch {
            await MainActor.run {
                resendStatusMessage = "Unable to check existing reset status."
            }
        }
    }

    private func submitNewPassword() {
        guard isCodeSectionEnabled else {
            codeErrorMessage = "Request a reset code first."
            return
        }
        guard !code.isEmpty else {
            codeErrorMessage = "Enter the verification code."
            return
        }
        guard newPassword.count >= 12 else {
            codeErrorMessage = "Password must be at least 12 characters."
            return
        }
        guard newPassword == confirmPassword else {
            codeErrorMessage = "Passwords do not match."
            return
        }

        isSubmitting = true
        codeErrorMessage = nil

        Task {
            do {
                let service = EmailAuthService(manifest: appState.manifest)
                try await service.confirmPasswordReset(email: email, code: code, newPassword: newPassword)
                let session = try await service.login(email: email, password: newPassword)
                await MainActor.run {
                    appState.handleLoginSuccess(session)
                    isSubmitting = false
                }
                AnalyticsClient.shared.track(.emailPasswordResetConfirmed, properties: [
                    "emailDomain": emailDomain(from: email)
                ])
            } catch let apiError as APIError {
                await MainActor.run {
                    codeErrorMessage = apiError.message ?? "Unable to update password."
                    isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    codeErrorMessage = "Unexpected error. Please try again."
                    isSubmitting = false
                }
            }
        }
    }

    private func startResendCooldown() {
        forgotResendCooldownUntil = Date().addingTimeInterval(Double(resendCooldownSeconds)).timeIntervalSince1970
        updateResendCooldown()
    }

    private func resetFlow() {
        email = ""
        code = ""
        newPassword = ""
        confirmPassword = ""
        deliveryDescription = nil
        infoMessage = nil
        errorMessage = nil
        codeErrorMessage = nil
        resendStatusMessage = nil
        isCodeSectionEnabled = false
        resendCooldownRemaining = 0
        forgotResendCooldownUntil = 0
        focusedField = .email
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

    private func passwordInput(
        title: String,
        text: Binding<String>,
        isVisible: Binding<Bool>,
        field: ForgotPasswordField
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
                    .foregroundStyle(Color.secondaryText)
            }
        }
    }

    private func emailDomain(from email: String) -> String {
        email.split(separator: "@").last.map(String.init) ?? "unknown"
    }
}

private enum ForgotPasswordField: Hashable {
    case email
    case code
    case newPassword
    case confirmPassword
}
