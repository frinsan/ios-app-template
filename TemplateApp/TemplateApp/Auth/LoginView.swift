import SwiftUI
import Combine

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Button(action: { startLogin(provider: .apple) }) {
                    pillButtonLabel(icon: "apple.logo", text: HostedUIProvider.apple.displayName)
                }
                .buttonStyle(DarkPillButtonStyle())

                Button(action: { startLogin(provider: .google) }) {
                    pillButtonLabel(icon: "g.circle", text: HostedUIProvider.google.displayName)
                }
                .buttonStyle(DarkPillButtonStyle())

                if isLoading {
                    ProgressView()
                        .tint(Color.primaryText)
                }

                NavigationLink {
                    EmailSignUpView()
                } label: {
                    pillButtonLabel(icon: "envelope.fill", text: "Continue with Email")
                }
                .buttonStyle(DarkPillButtonStyle())

                NavigationLink {
                    EmailLoginView()
                } label: {
                    pillButtonLabel(icon: "key.fill", text: "Log In")
                }
                .buttonStyle(DarkPillButtonStyle())

                legalDisclaimer
                    .padding(.top, 12)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .navigationTitle("Sign up or log in")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.cardBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .background(
            LinearGradient(
                colors: [Color.appBackground, Color.cardBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
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

extension LoginView {
    private func pillButtonLabel(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline.bold())
            Text(text)
                .font(.headline.weight(.semibold))
            Spacer()
        }
        .foregroundStyle(Color.primaryText)
        .padding(.horizontal, 18)
        .frame(height: 56)
    }

    @ViewBuilder
    private var legalDisclaimer: some View {
        if let terms = appState.manifest.legal?.termsUrl,
           let privacy = appState.manifest.legal?.privacyUrl {
            Text("By signing up or logging in you agree to our [Terms of Service](\(terms.absoluteString)) and [Privacy Policy](\(privacy.absoluteString)).")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.secondaryText)
                .tint(Color.primaryAccent)
        } else {
            Text("By signing up or logging in you agree to our Terms of Service and Privacy Policy.")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.secondaryText)
        }
    }

    private func emailDomain(from email: String) -> String {
        email.split(separator: "@").last.map(String.init) ?? "unknown"
    }
}

struct EmailSignUpView: View {
    enum Step {
        case emailEntry
        case details
    }

    enum EmailFlowStatus: Equatable {
        case new
        case pending(String?)
    }

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .emailEntry
    @State private var emailInput = ""
    @State private var lockedEmail = ""
    @State private var emailStatus: EmailFlowStatus?
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var verificationCode = ""
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @State private var errorMessage: String?
    @State private var serverErrorMessage: String?
    @State private var codeErrorMessage: String?
    @State private var isCheckingEmail = false
    @State private var isSubmitting = false
    @State private var isConfirmingCode = false
    @State private var isResendingCode = false
    @State private var codeInfoMessage: String?
    @State private var resendStatusMessage: String?
    @State private var isCodeSectionEnabled = false
    @State private var resendCooldownRemaining = 0
    @FocusState private var focusedField: SignUpField?
    @AppStorage("EmailSignUpResendCooldownUntil") private var signupResendCooldownUntil: Double = 0
    private let resendTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            switch step {
            case .emailEntry:
                emailEntryStep
            case .details:
                detailsStep
            }
        }
        .lightModeTextColor()
        .navigationTitle("Sign up with email")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: appState.latestLoginSuccessID) { _, _ in
            dismiss()
        }
        .onAppear { updateResendCooldown() }
        .onReceive(resendTimer) { _ in
            tickResendCooldown()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .alert("Unable to sign up", isPresented: Binding(
            get: { serverErrorMessage != nil },
            set: { if !$0 { serverErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                serverErrorMessage = nil
            }
        } message: {
            Text(serverErrorMessage ?? "")
        }
    }
}

private struct ForgotPasswordLinkRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Forgot password?")
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.secondary)
    }
}

private struct MonogramIcon: View {
    let letter: String

    var body: some View {
        Text(letter)
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.primary)
            .frame(width: 28, height: 28)
            .overlay(
                Circle()
                    .stroke(Color.primary, lineWidth: 2)
            )
    }
}
extension EmailSignUpView {
    private var accentColor: Color {
        Color.primaryAccent
    }

    private var isEmailInputValid: Bool {
        EmailSignUpValidator.isValidEmail(emailInput.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var isDetailsFormValid: Bool {
        EmailSignUpValidator.isFormValid(email: lockedEmail, password: password, confirmPassword: confirmPassword)
    }

    private var passwordValidationMessage: String? {
        guard !password.isEmpty else { return nil }
        return password.count >= 12 ? nil : "Password must be at least 12 characters."
    }

    private var confirmPasswordValidationMessage: String? {
        guard !confirmPassword.isEmpty else { return nil }
        guard !password.isEmpty else { return nil }
        return password == confirmPassword ? nil : "Passwords must match."
    }

    @ViewBuilder
    private var emailEntryStep: some View {
        Section {
            TextField("Email", text: $emailInput)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
        } footer: {
            Text("We'll check if this email already has an account before continuing.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        if let errorMessage {
            Section {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }

        Section {
            Button(action: submitEmailAddress) {
                if isCheckingEmail {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("Continue").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(ConsistentButtonStyle(accentColor: accentColor))
            .disabled(!isEmailInputValid || isCheckingEmail)
        }
    }

    @ViewBuilder
    private var detailsStep: some View {
        Section {
            LabeledContent("Email", value: lockedEmail)
            Button("Change email") {
                resetToEmailEntry()
            }
            .font(.footnote)
        }

        if case let .pending(description) = emailStatus {
            Section {
                Text("We found a pending sign-up. Enter the verification code we sent to \(description ?? lockedEmail) to finish.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }

        Section {
            passwordInput(
                title: "Password (min 12 characters)",
                text: $password,
                isVisible: $isPasswordVisible,
                field: .password
            )
            if let message = passwordValidationMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            passwordInput(
                title: "Confirm password",
                text: $confirmPassword,
                isVisible: $isConfirmPasswordVisible,
                field: .confirmPassword
            )
            if let message = confirmPasswordValidationMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }

        if let errorMessage {
            Section {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }

        if emailStatus == nil || emailStatus == .new {
            Section {
                Button(action: startSignUp) {
                    if isSubmitting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Get verification code").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(ConsistentButtonStyle(accentColor: accentColor))
                .disabled(!isDetailsFormValid || isSubmitting)
            }
        }

        verificationSection
    }

    @ViewBuilder
    private var verificationSection: some View {
        Section("Verification Code") {
            TextField("6-digit code", text: $verificationCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .disabled(!isCodeSectionEnabled)
                .focused($focusedField, equals: .verificationCode)

            if let codeErrorMessage {
                Text(codeErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if let codeInfoMessage {
                Text(codeInfoMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let resendStatusMessage {
                Text(resendStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if resendCooldownRemaining > 0 {
                Text("You can resend in \(resendCooldownRemaining)s.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button(action: confirmCode) {
                if isConfirmingCode {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("Confirm code").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(ConsistentButtonStyle(accentColor: accentColor))
            .disabled(!isCodeSectionEnabled || verificationCode.isEmpty || isConfirmingCode)

            Button("Resend code") {
                resendVerificationCode()
            }
            .disabled(!isCodeSectionEnabled || isResendingCode || resendCooldownRemaining > 0)
        }
    }

    private func submitEmailAddress() {
        guard isEmailInputValid else {
            errorMessage = "Enter a valid email."
            return
        }
        let normalized = emailInput.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = nil
        isCheckingEmail = true

        Task {
            do {
                let service = EmailAuthService(manifest: appState.manifest)
                let status = try await service.checkEmailStatus(email: normalized)
                await MainActor.run {
                    handleEmailStatus(status, email: normalized)
                }
            } catch let apiError as APIError {
                await MainActor.run {
                    serverErrorMessage = apiError.message ?? "Unable to check email."
                    isCheckingEmail = false
                }
            } catch {
                await MainActor.run {
                    serverErrorMessage = "Unexpected error. Please try again."
                    isCheckingEmail = false
                }
            }
        }
    }

    private func handleEmailStatus(_ result: EmailAuthService.EmailStatusResult, email: String) {
        isCheckingEmail = false
        switch result.status {
        case .confirmed:
            serverErrorMessage = "An account already exists for \(email). Try logging in instead."
        case .new:
            lockedEmail = email
            emailStatus = .new
            step = .details
            resetDetailsState(preservingEmail: true)
            isCodeSectionEnabled = false
            codeInfoMessage = "Tap Create account to receive a verification code."
        case .pendingConfirmation:
            lockedEmail = email
            emailStatus = .pending(result.deliveryDescription)
            step = .details
            resetDetailsState(preservingEmail: true)
            enableCodeEntry(message: "Enter the code we sent to \(result.deliveryDescription ?? email).")
        }
    }

    private func startSignUp() {
        guard !lockedEmail.isEmpty else { return }
        guard isDetailsFormValid else {
            errorMessage = "Check your password entries before continuing."
            return
        }
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let service = EmailAuthService(manifest: appState.manifest)
                let result = try await service.signUp(
                    email: lockedEmail,
                    password: password,
                    givenName: nil,
                    familyName: nil
                )
                await handleSignUpResult(result: result)
                AnalyticsClient.shared.track(.emailSignupSubmitted, properties: [
                    "emailDomain": emailDomain(from: lockedEmail)
                ])
            } catch let apiError as APIError {
                await MainActor.run {
                    errorMessage = apiError.message ?? "Unable to start email sign-up."
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

    private func handleSignUpResult(result: EmailAuthService.EmailSignUpResult) async {
        await MainActor.run {
            isSubmitting = false
            guard result.requiresConfirmation else {
                serverErrorMessage = "Unexpected response from server. Please try again."
                return
            }
            emailStatus = .pending(result.deliveryDescription)
            enableCodeEntry(message: result.message)
        }
    }

    private func confirmCode() {
        guard !lockedEmail.isEmpty else { return }
        guard isCodeSectionEnabled else {
            codeErrorMessage = "Send yourself a verification code first."
            return
        }
        guard !verificationCode.isEmpty else {
            codeErrorMessage = "Enter the verification code."
            return
        }
        guard !isConfirmingCode else { return }
        codeErrorMessage = nil
        isConfirmingCode = true

        Task {
            do {
                let service = EmailAuthService(manifest: appState.manifest)
                let session = try await service.confirm(email: lockedEmail, password: password, code: verificationCode)
                await MainActor.run {
                    isConfirmingCode = false
                    appState.handleLoginSuccess(session)
                }
            } catch let apiError as APIError {
                await MainActor.run {
                    codeErrorMessage = apiError.message ?? "Unable to confirm code."
                    isConfirmingCode = false
                }
            } catch {
                await MainActor.run {
                    codeErrorMessage = "Unexpected error. Please try again."
                    isConfirmingCode = false
                }
            }
        }
    }

    private func resendVerificationCode() {
        guard !lockedEmail.isEmpty else { return }
        guard isCodeSectionEnabled else { return }
        guard !isResendingCode else { return }
        isResendingCode = true
        codeErrorMessage = nil

        Task {
            do {
                let service = EmailAuthService(manifest: appState.manifest)
                try await service.resendCode(email: lockedEmail)
                await MainActor.run {
                    resendStatusMessage = "New code sent to \(lockedEmail)."
                    isResendingCode = false
                    signupResendCooldownUntil = Date().addingTimeInterval(60).timeIntervalSince1970
                    updateResendCooldown()
                }
                AnalyticsClient.shared.track(.emailSignupResentCode, properties: [
                    "emailDomain": emailDomain(from: lockedEmail)
                ])
            } catch let apiError as APIError {
                await MainActor.run {
                    resendStatusMessage = apiError.message ?? "Unable to resend verification code."
                    isResendingCode = false
                }
            } catch {
                await MainActor.run {
                    resendStatusMessage = "Unexpected error. Please try again."
                    isResendingCode = false
                }
            }
        }
    }

    private func enableCodeEntry(message: String?) {
        isCodeSectionEnabled = true
        codeInfoMessage = message
        resendStatusMessage = nil
        verificationCode = ""
        updateResendCooldown()
        focusedField = .verificationCode
    }

    private func resetToEmailEntry() {
        step = .emailEntry
        emailStatus = nil
        lockedEmail = ""
        password = ""
        confirmPassword = ""
        verificationCode = ""
        errorMessage = nil
        codeErrorMessage = nil
        serverErrorMessage = nil
        codeInfoMessage = nil
        resendStatusMessage = nil
        isCodeSectionEnabled = false
        focusedField = .email
    }

    private func resetDetailsState(preservingEmail: Bool) {
        password = ""
        confirmPassword = ""
        verificationCode = ""
        errorMessage = nil
        codeErrorMessage = nil
        codeInfoMessage = nil
        resendStatusMessage = nil
        isCodeSectionEnabled = false
        if preservingEmail {
            focusedField = .password
        } else {
            focusedField = nil
        }
    }

    private func updateResendCooldown() {
        let remaining = Int(signupResendCooldownUntil - Date().timeIntervalSince1970)
        resendCooldownRemaining = max(0, remaining)
    }

    private func tickResendCooldown() {
        guard resendCooldownRemaining > 0 else { return }
        resendCooldownRemaining -= 1
        if resendCooldownRemaining <= 0 {
            resendCooldownRemaining = 0
            signupResendCooldownUntil = 0
        }
    }

    private func emailDomain(from email: String) -> String {
        email.split(separator: "@").last.map(String.init) ?? "unknown"
    }

    @ViewBuilder
    private func passwordInput(title: String, text: Binding<String>, isVisible: Binding<Bool>, field: SignUpField) -> some View {
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
}

struct EmailLoginView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var isForgotPasswordPresented = false
    @FocusState private var focusedField: LoginField?
    @State private var pendingConfirmation: PendingConfirmation?

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)

                HStack {
                    Group {
                        if isPasswordVisible {
                            TextField("Password", text: $password)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("Password", text: $password)
                        }
                    }
                    .focused($focusedField, equals: .password)

                    Button(action: { isPasswordVisible.toggle() }) {
                        Image(systemName: isPasswordVisible ? "eye" : "eye.slash")
                            .foregroundStyle(.secondary)
                    }
                }
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
                        Text("Log in with email").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(ConsistentButtonStyle(accentColor: accentColor))
                .disabled(isSubmitting)
            }

            Section {
                ForgotPasswordLinkRow(action: { isForgotPasswordPresented = true })
            }
        }
        .lightModeTextColor()
        .navigationTitle("Log in with email")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: appState.latestLoginSuccessID) { _, _ in
            dismiss()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .sheet(isPresented: $isForgotPasswordPresented) {
            NavigationStack {
                ForgotPasswordRequestView()
            }
        }
        .navigationDestination(item: $pendingConfirmation) { pending in
            EmailConfirmView(pending: pending)
        }
    }

    private func submit() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Email and password are required."
            return
        }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let service = EmailAuthService(manifest: appState.manifest)
                let session = try await service.login(email: email, password: password)
                await MainActor.run {
                    appState.handleLoginSuccess(session)
                    isSubmitting = false
                    dismiss()
                }
                AnalyticsClient.shared.track(.emailLoginAttempt, properties: [
                    "status": "success",
                    "emailDomain": emailDomain(from: email)
                ])
            } catch let apiError as APIError {
                if await handleLoginPendingConfirmation(apiError: apiError) {
                    return
                }
                await MainActor.run {
                    switch apiError {
                    case let .responseError(message, _):
                        errorMessage = message ?? "Unable to log in."
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
        Color.primaryAccent
    }

    private func emailDomain(from email: String) -> String {
        email.split(separator: "@").last.map(String.init) ?? "unknown"
    }

    private func handleLoginPendingConfirmation(apiError: APIError) async -> Bool {
        guard case let .responseError(message, code) = apiError, code == "USER_NOT_CONFIRMED" else {
            return false
        }
        let service = EmailAuthService(manifest: appState.manifest)
        do {
            try await service.resendCode(email: email)
        } catch {
            // Ignore resend failures; the confirm screen exposes manual retry.
        }
        await MainActor.run {
            pendingConfirmation = PendingConfirmation(
                email: email,
                password: password,
                message: message ?? "Finish confirming your account to continue.",
                deliveryDescription: email
            )
            isSubmitting = false
            errorMessage = nil
        }
        return true
    }

}

struct EmailConfirmView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let pending: PendingConfirmation
    @State private var code = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var isResending = false
    @State private var resendStatus: String?
    @State private var resendCooldownRemaining = 0
    @AppStorage("EmailSignUpResendCooldownUntil") private var signupResendCooldownUntil: Double = 0
    private let resendCooldownSeconds = 60
    private let resendTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section(footer: Text(pending.message).font(.footnote)) {
                Text("We sent a verification code to \(pending.deliveryDescription).")
                TextField("6-digit code", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
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
                        Text("Confirm and continue").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(ConsistentButtonStyle(accentColor: accentColor))
                .disabled(isSubmitting)
            }
        }
        .lightModeTextColor()
        .navigationTitle("Enter verification code")
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

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let service = EmailAuthService(manifest: appState.manifest)
                let session = try await service.confirm(email: pending.email, password: pending.password, code: code)
                await MainActor.run {
                    appState.handleLoginSuccess(session)
                    isSubmitting = false
                    dismiss()
                }
            } catch let apiError as APIError {
                await MainActor.run {
                    switch apiError {
                    case let .responseError(message, _):
                        errorMessage = message ?? "Unable to confirm code."
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
        Color.primaryAccent
    }

    private func resendCode() async {
        guard !isResending else { return }
        isResending = true
        do {
            let service = EmailAuthService(manifest: appState.manifest)
            try await service.resendCode(email: pending.email)
            await MainActor.run {
                resendStatus = "Code resent to \(pending.deliveryDescription)."
                isResending = false
                signupResendCooldownUntil = Date().addingTimeInterval(Double(resendCooldownSeconds)).timeIntervalSince1970
                updateResendCooldown()
            }
            AnalyticsClient.shared.track(.emailSignupResentCode, properties: [
                "emailDomain": emailDomain(from: pending.email)
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

    private func emailDomain(from email: String) -> String {
        email.split(separator: "@").last.map(String.init) ?? "unknown"
    }

    private func updateResendCooldown() {
        let remaining = Int(signupResendCooldownUntil - Date().timeIntervalSince1970)
        resendCooldownRemaining = max(0, remaining)
    }

    private func tickResendCooldown() {
        guard resendCooldownRemaining > 0 else { return }
        resendCooldownRemaining -= 1
        if resendCooldownRemaining <= 0 {
            resendCooldownRemaining = 0
            signupResendCooldownUntil = 0
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AppState())
}

struct PendingConfirmation: Identifiable, Hashable {
    let id = UUID()
    let email: String
    let password: String
    let message: String
    let deliveryDescription: String
}

private enum SignUpField: Hashable {
    case email
    case password
    case confirmPassword
    case verificationCode
}

private enum LoginField: Hashable {
    case email
    case password
}
private struct DarkPillButtonStyle: ButtonStyle {
    var accentColor: Color = .primaryAccent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(accentColor.opacity(configuration.isPressed ? 0.85 : 1), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.dividerColor.opacity(0.6), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
