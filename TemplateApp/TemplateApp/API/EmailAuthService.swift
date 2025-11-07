import Foundation

struct EmailAuthService {
    let manifest: AppManifest
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    func signUp(email: String, password: String, givenName: String?, familyName: String?) async throws -> AuthSession {
        let payload = SignUpPayload(email: email, password: password, givenName: givenName, familyName: familyName)
        return try await send(path: "/v1/auth/email/signup", payload: payload)
    }

    func login(email: String, password: String) async throws -> AuthSession {
        let payload = LoginPayload(email: email, password: password)
        return try await send(path: "/v1/auth/email/login", payload: payload)
    }

    private func send<Body: Encodable>(path: String, payload: Body) async throws -> AuthSession {
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let url = manifest.baseURL.appendingPathComponent(cleanPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 400 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.responseError(message)
        }

        let tokens = try decoder.decode(TokenResponse.self, from: data)
        return try AuthSessionBuilder.build(from: tokens)
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

    struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String?
        let idToken: String
        let expiresIn: Int?
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
