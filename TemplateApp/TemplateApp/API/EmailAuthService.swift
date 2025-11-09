import Foundation

struct EmailAuthService {
    let manifest: AppManifest
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    func signUp(email: String, password: String, givenName: String?, familyName: String?) async throws -> EmailSignUpResult {
        let payload = SignUpPayload(email: email, password: password, givenName: givenName, familyName: familyName)
        let response: SignUpResponse = try await post(path: "/v1/auth/email/signup", payload: payload)
        return EmailSignUpResult(
            message: response.message,
            deliveryMedium: response.deliveryMedium,
            destination: response.destination
        )
    }

    func confirm(email: String, password: String, code: String) async throws -> AuthSession {
        let payload = ConfirmPayload(email: email, password: password, code: code)
        let tokens: TokenResponse = try await post(path: "/v1/auth/email/confirm", payload: payload)
        return try AuthSessionBuilder.build(from: tokens)
    }

    func login(email: String, password: String) async throws -> AuthSession {
        let payload = LoginPayload(email: email, password: password)
        let tokens: TokenResponse = try await post(path: "/v1/auth/email/login", payload: payload)
        return try AuthSessionBuilder.build(from: tokens)
    }

    func resendCode(email: String) async throws {
        let payload = ResendPayload(email: email)
        let _: ResendResponse = try await post(path: "/v1/auth/email/resend", payload: payload)
    }

    func startPasswordReset(email: String) async throws -> EmailPasswordResetResult {
        let payload = ForgotPasswordRequestPayload(email: email)
        let response: ForgotPasswordResponse = try await post(path: "/v1/auth/email/forgot", payload: payload)
        return EmailPasswordResetResult(
            message: response.message,
            deliveryMedium: response.deliveryMedium,
            destination: response.destination
        )
    }

    func confirmPasswordReset(email: String, code: String, newPassword: String) async throws {
        let payload = ForgotPasswordConfirmPayload(email: email, code: code, newPassword: newPassword)
        let _: ForgotPasswordConfirmResponse = try await post(
            path: "/v1/auth/email/forgot/confirm",
            payload: payload
        )
    }

    private func post<Body: Encodable, Response: Decodable>(path: String, payload: Body) async throws -> Response {
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let url = manifest.baseURL.appendingPathComponent(cleanPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(manifest.appId, forHTTPHeaderField: "x-app-id")
        if let clientId = manifest.auth.cognitoClientId {
            request.setValue(clientId, forHTTPHeaderField: "x-app-client-id")
        }
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.responseError("No response from server")
        }

        if httpResponse.statusCode >= 400 {
            if let errorPayload = try? decoder.decode(APIErrorPayload.self, from: data) {
                throw APIError.responseError(errorPayload.message ?? "Request failed")
            }
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.responseError(message)
        }

        return try decoder.decode(Response.self, from: data)
    }

    private struct SignUpPayload: Encodable {
        let email: String
        let password: String
        let givenName: String?
        let familyName: String?
    }

    private struct LoginPayload: Encodable {
        let email: String
        let password: String
    }

    private struct ConfirmPayload: Encodable {
        let email: String
        let password: String
        let code: String
    }

    private struct ResendPayload: Encodable {
        let email: String
    }

    private struct ResendResponse: Decodable {
        let message: String
    }

    private struct ForgotPasswordRequestPayload: Encodable {
        let email: String
    }

    private struct ForgotPasswordConfirmPayload: Encodable {
        let email: String
        let code: String
        let newPassword: String
    }

    private struct ForgotPasswordResponse: Decodable {
        let status: String
        let message: String
        let deliveryMedium: String?
        let destination: String?
    }

    private struct ForgotPasswordConfirmResponse: Decodable {
        let status: String
        let message: String?
    }

    private struct SignUpResponse: Decodable {
        let status: String
        let message: String
        let deliveryMedium: String?
        let destination: String?
    }

    struct EmailSignUpResult {
        let message: String
        let deliveryMedium: String?
        let destination: String?

        var deliveryDescription: String {
            if let destination {
                return destination
            }
            if let deliveryMedium {
                return deliveryMedium
            }
            return "your email"
        }
    }

    struct EmailPasswordResetResult {
        let message: String
        let deliveryMedium: String?
        let destination: String?

        var deliveryDescription: String {
            if let destination {
                return destination
            }
            if let deliveryMedium {
                return deliveryMedium
            }
            return "your email"
        }
    }

    struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String?
        let idToken: String
        let expiresIn: Int?
    }

    private struct APIErrorPayload: Decodable {
        let message: String?
    }
}

enum AuthSessionBuilder {
    static func build(from tokens: EmailAuthService.TokenResponse) throws -> AuthSession {
        let claims = try HostedUILoginController.decodeJWTClaims(tokens.idToken)
        let user = AuthenticatedUser(
            subject: claims["sub"] as? String ?? UUID().uuidString,
            email: claims["email"] as? String,
            givenName: claims["given_name"] as? String,
            familyName: claims["family_name"] as? String
        )

        return AuthSession(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            idToken: tokens.idToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokens.expiresIn ?? 3600)),
            user: user
        )
    }
}
