import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isLoading = false
    @State private var isEmailLoading = false
    @State private var emailMode: EmailAuthMode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var givenName = ""
    @State private var familyName = ""
    @State private var emailError: String?

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

            Divider()
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 12) {
                Text("Use email instead")
                    .font(.headline)

                Picker("Mode", selection: $emailMode) {
                    ForEach(EmailAuthMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()

                SecureField("Password", text: $password)

                if emailMode == .signup {
                    SecureField("Confirm password", text: $confirmPassword)
                    TextField("First name (optional)", text: $givenName)
                    TextField("Last name (optional)", text: $familyName)
                }

                if let emailError {
                    Text(emailError)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                Button(action: startEmailFlow) {
                    if isEmailLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(emailMode.buttonTitle)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isEmailLoading)
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

    private func startEmailFlow() {
        guard case .signedOut = appState.authState else { return }
        guard validateEmailInput() else { return }
        isEmailLoading = true
        emailError = nil

        Task {
            do {
                let service = EmailAuthService(manifest: appState.manifest)
                let session: AuthSession

                switch emailMode {
                case .login:
                    session = try await service.login(email: email, password: password)
                case .signup:
                    session = try await service.signUp(
                        email: email,
                        password: password,
                        givenName: givenName.isEmpty ? nil : givenName,
                        familyName: familyName.isEmpty ? nil : familyName
                    )
                }

                await MainActor.run {
                    appState.handleLoginSuccess(session)
                    resetEmailForm()
                    isEmailLoading = false
                }
            } catch let apiError as APIError {
                await MainActor.run {
                    switch apiError {
                    case .responseError(let message):
                        emailError = message ?? "Unable to authenticate with email"
                    }
                    isEmailLoading = false
                }
            } catch {
                await MainActor.run {
                    emailError = "Unexpected error. Please try again."
                    isEmailLoading = false
                }
            }
        }
    }

    private func validateEmailInput() -> Bool {
        guard !email.isEmpty, !password.isEmpty else {
            emailError = "Email and password are required."
            return false
        }

        if emailMode == .signup, password != confirmPassword {
            emailError = "Passwords do not match."
            return false
        }

        return true
    }

    private func resetEmailForm() {
        email = ""
        password = ""
        confirmPassword = ""
        givenName = ""
        familyName = ""
        emailError = nil
    }
}

#Preview {
    LoginView()
        .environmentObject(AppState())
}

enum EmailAuthMode: CaseIterable {
    case login
    case signup

    var title: String {
        switch self {
        case .login: return "Log in"
        case .signup: return "Sign up"
        }
    }

    var buttonTitle: String {
        switch self {
        case .login: return "Continue with Email"
        case .signup: return "Create account"
        }
    }
}
