import SwiftUI
import Combine

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Sign up or log in")
                    .font(.largeTitle.bold())
                Button(action: { startLogin(provider: .apple) }) {
                    Label(HostedUIProvider.apple.displayName, systemImage: "apple.logo")
                }
                .buttonStyle(ConsistentButtonStyle(accentColor: accentColor))

                Button(action: { startLogin(provider: .google) }) {
                    Label {
                        Text(HostedUIProvider.google.displayName)
                    } icon: {
                        MonogramIcon(letter: "G")
                    }
                }
                .buttonStyle(ConsistentButtonStyle(accentColor: accentColor))

                if isLoading {
                    ProgressView()
                }

                NavigationLink {
                    EmailSignUpView()
                } label: {
                    Label("Continue with Email", systemImage: "envelope.fill")
                }
                .themedCTA(accentColor: accentColor)

                NavigationLink {
                    EmailLoginView()
                } label: {
                    Label("Log In", systemImage: "key.fill")
                }
                .themedCTA(accentColor: accentColor)

                Text("By signing up or logging in you agree to our Terms of Service and Privacy Policy.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.top, 16)
            }
            .padding()
        }
        .lightModeTextColor()
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
    private var accentColor: Color {
        Color(hex: appState.manifest.theme.accentHex)
    }

    private func emailDomain(from email: String) -> String {
        email.split(separator: "@").last.map(String.init) ?? "unknown"
    }
}

struct EmailSignUpView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var givenName = ""
    @State private var familyName = ""
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @State private var errorMessage: String?
    @State private var serverErrorMessage: String?
    @State private var isSubmitting = false
    @State private var pendingConfirmation: PendingConfirmation?
    @FocusState private var focusedField: SignUpField?

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)

                passwordInput(
                    title: "Password (min 12 characters)",
                    text: $password,
                    isVisible: $isPasswordVisible,
                    field: .password
                )

                passwordInput(
                    title: "Confirm password",
                    text: $confirmPassword,
                    isVisible: $isConfirmPasswordVisible,
                    field: .confirmPassword
                )
            }

            Section("Optional") {
                TextField("First name", text: $givenName)
                    .focused($focusedField, equals: .givenName)
                TextField("Last name", text: $familyName)
                    .focused($focusedField, equals: .familyName)
            }

            Section {
                Button(action: submit) {
                    if isSubmitting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Sign up").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(ConsistentButtonStyle(accentColor: accentColor))
                .disabled(isSubmitting || !isFormValid)
            }
        }
        .lightModeTextColor()
        .navigationTitle("Sign up with email")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $pendingConfirmation) { pending in
            EmailConfirmView(pending: pending)
        }
        .onChange(of: appState.latestLoginSuccessID) { _ in
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
        Color(hex: appState.manifest.theme.accentHex)
    }

    private var isFormValid: Bool {
        EmailSignUpValidator.isFormValid(email: email, password: password, confirmPassword: confirmPassword)
    }

    private func submit() {
        guard !isSubmitting else { return }
        guard validateInput() else { return }
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let service = EmailAuthService(manifest: appState.manifest)
                let result = try await service.signUp(
                    email: email,
                    password: password,
                    givenName: givenName.isEmpty ? nil : givenName,
                    familyName: familyName.isEmpty ? nil : familyName
                )
                await handleSignUpResult(result: result)
                AnalyticsClient.shared.track(.emailSignupSubmitted, properties: [
                    "emailDomain": emailDomain(from: email)
                ])
            } catch let apiError as APIError {
                if await handlePendingConfirmation(apiError: apiError) {
                    return
                }
                await MainActor.run {
                    switch apiError {
                    case .responseError(let message):
                        let displayMessage = message ?? "Unable to start email sign-up."
                        errorMessage = displayMessage
                        serverErrorMessage = displayMessage
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

    private func validateInput() -> Bool {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Email and password are required."
            return false
        }
        guard EmailSignUpValidator.isValidEmail(email) else {
            errorMessage = "Enter a valid email address."
            return false
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return false
        }
        return true
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

    private func emailDomain(from email: String) -> String {
        email.split(separator: "@").last.map(String.init) ?? "unknown"
    }

    private func handleSignUpResult(result: EmailAuthService.EmailSignUpResult) async {
        await MainActor.run {
            pendingConfirmation = PendingConfirmation(
                email: email,
                password: password,
                message: result.message,
                deliveryDescription: result.deliveryDescriptionString
            )
            isSubmitting = false
            errorMessage = nil
            serverErrorMessage = nil
        }
    }

    private func handlePendingConfirmation(apiError: APIError) async -> Bool {
        guard case .responseError(let message?) = apiError else {
            return false
        }
        let normalizedMessage = message.lowercased()
        guard normalizedMessage.contains("pending confirmation") || normalizedMessage.contains("account already exists") else {
            return false
        }

        let service = EmailAuthService(manifest: appState.manifest)
        do {
            try await service.resendCode(email: email)
        } catch {
            return false
        }
        await MainActor.run {
            pendingConfirmation = PendingConfirmation(
                email: email,
                password: password,
                message: "We found a pending sign-up. Enter the verification code we sent to \(email).",
                deliveryDescription: "your email"
            )
            isSubmitting = false
            errorMessage = nil
            serverErrorMessage = nil
        }
        return true
    }
}

struct EmailLoginView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var isPasswordVisible = false
    @State private var isForgotPasswordPresented = false
    @FocusState private var focusedField: LoginField?

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
        .onChange(of: appState.latestLoginSuccessID) { _ in
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
                await MainActor.run {
                    switch apiError {
                    case .responseError(let message):
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
        Color(hex: appState.manifest.theme.accentHex)
    }

    private func emailDomain(from email: String) -> String {
        email.split(separator: "@").last.map(String.init) ?? "unknown"
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
                    case .responseError(let message):
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
        Color(hex: appState.manifest.theme.accentHex)
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
                case .responseError(let message):
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
    case givenName
    case familyName
}

private enum LoginField: Hashable {
    case email
    case password
}
