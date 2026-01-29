@preconcurrency import AuthenticationServices
import Foundation
import SwiftUI
import UIKit

enum HostedUIProvider: String {
    case apple
    case google

    var displayName: String {
        switch self {
        case .apple: return "Continue with Apple"
        case .google: return "Continue with Google"
        }
    }

    var hostedUIIdentifier: String {
        switch self {
        case .apple: return "SignInWithApple"
        case .google: return "Google"
        }
    }
}

enum HostedUILoginError: Error {
    case invalidConfiguration
    case cancelled
    case missingCallback
    case tokenExchangeFailed
}

enum RefreshTokenError: Error {
    case authFailed
    case transient
}

struct HostedUILoginController {
    @MainActor
    static func signIn(provider: HostedUIProvider, manifest: AppManifest) async throws -> AuthSession {
        guard let clientId = manifest.auth.cognitoClientId,
              let scheme = manifest.auth.scheme,
              let region = manifest.auth.region,
              let domain = manifest.auth.hostedUIDomain, !domain.isEmpty
        else {
            throw HostedUILoginError.invalidConfiguration
        }

        let redirectUri = "\(scheme)://auth"
        guard var components = URLComponents(string: "https://\(domain)/oauth2/authorize") else {
            throw HostedUILoginError.invalidConfiguration
        }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "identity_provider", value: provider.hostedUIIdentifier)
        ]

        guard let authUrl = components.url else {
            throw HostedUILoginError.invalidConfiguration
        }

        let callbackURL = try await presentHostedUI(url: authUrl, callbackScheme: scheme)
        return try await exchangeCode(
            callbackURL: callbackURL,
            clientId: clientId,
            redirectUri: redirectUri,
            region: region,
            domain: domain
        )
    }

    @MainActor
    static func logout(manifest: AppManifest) async throws {
        guard let domain = manifest.auth.hostedUIDomain,
              let clientId = manifest.auth.cognitoClientId,
              let scheme = manifest.auth.scheme else {
            throw HostedUILoginError.invalidConfiguration
        }

        guard var components = URLComponents(string: "https://\(domain)/logout") else {
            throw HostedUILoginError.invalidConfiguration
        }
        let logoutRedirect = "\(scheme)://auth"
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "logout_uri", value: logoutRedirect)
        ]

        guard let logoutURL = components.url else {
            throw HostedUILoginError.invalidConfiguration
        }

        _ = try await presentHostedUI(url: logoutURL, callbackScheme: scheme)
    }

    static func refreshSession(manifest: AppManifest, refreshToken: String) async throws -> AuthSession {
        guard let domain = manifest.auth.hostedUIDomain,
              let clientId = manifest.auth.cognitoClientId else {
            throw HostedUILoginError.invalidConfiguration
        }

        var request = URLRequest(url: URL(string: "https://\(domain)/oauth2/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "grant_type=refresh_token&client_id=\(clientId)&refresh_token=\(refreshToken)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RefreshTokenError.transient
        }
        guard httpResponse.statusCode == 200 else {
            if let errorPayload = try? JSONDecoder().decode(TokenErrorResponse.self, from: data),
               errorPayload.error == "invalid_grant" {
                throw RefreshTokenError.authFailed
            }
            if let payload = String(data: data, encoding: .utf8) {
                print("[Auth] Refresh token failed: \(payload)")
            }
            throw RefreshTokenError.transient
        }

        let payload = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)
        let idTokenClaims = try decodeJWTClaims(payload.idToken)
        let user = AuthenticatedUser(
            subject: idTokenClaims["sub"] as? String ?? UUID().uuidString,
            email: idTokenClaims["email"] as? String,
            givenName: idTokenClaims["given_name"] as? String,
            familyName: idTokenClaims["family_name"] as? String
        )

        return AuthSession(
            accessToken: payload.accessToken,
            refreshToken: payload.refreshToken ?? refreshToken,
            idToken: payload.idToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(payload.expiresIn)),
            user: user
        )
    }

    @MainActor
    private static func presentHostedUI(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
                if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: HostedUILoginError.cancelled)
                    return
                }

                guard let callbackURL else {
                    continuation.resume(throwing: HostedUILoginError.missingCallback)
                    return
                }

                continuation.resume(returning: callbackURL)
            }
            session.presentationContextProvider = HostedUIPresentationAnchor.shared
            session.prefersEphemeralWebBrowserSession = true
            DispatchQueue.main.async {
                session.start()
            }
        }
    }

    private static func exchangeCode(
        callbackURL: URL,
        clientId: String,
        redirectUri: String,
        region: String,
        domain: String
    ) async throws -> AuthSession {
        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw HostedUILoginError.tokenExchangeFailed
        }

        var request = URLRequest(url: URL(string: "https://\(domain)/oauth2/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "grant_type=authorization_code&code=\(code)&client_id=\(clientId)&redirect_uri=\(redirectUri)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HostedUILoginError.tokenExchangeFailed
        }

        guard httpResponse.statusCode == 200 else {
            if let payload = String(data: data, encoding: .utf8) {
                print("[Auth] Token exchange failed: \(httpResponse.statusCode) - \(payload)")
            }
            throw HostedUILoginError.tokenExchangeFailed
        }

        let payload = try JSONDecoder().decode(TokenExchangeResponse.self, from: data)
        let idTokenClaims = try decodeJWTClaims(payload.idToken)
        let user = AuthenticatedUser(
            subject: idTokenClaims["sub"] as? String ?? UUID().uuidString,
            email: idTokenClaims["email"] as? String,
            givenName: idTokenClaims["given_name"] as? String,
            familyName: idTokenClaims["family_name"] as? String
        )

        let session = AuthSession(
            accessToken: payload.accessToken,
            refreshToken: payload.refreshToken,
            idToken: payload.idToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(payload.expiresIn)),
            user: user
        )

        try AuthSessionStorage.shared.store(session)
        return session
    }

    static func decodeJWTClaims(_ token: String) throws -> [String: Any] {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return [:] }
        var body = String(parts[1])
        let requiredLength = ((body.count + 3) / 4) * 4
        if body.count != requiredLength {
            body.append(String(repeating: "=", count: requiredLength - body.count))
        }
        guard let data = Data(base64Encoded: body) else { return [:] }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json ?? [:]
    }
}

@MainActor
private final class HostedUIPresentationAnchor: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = HostedUIPresentationAnchor()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow ?? ASPresentationAnchor()
    }
}

private struct TokenExchangeResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let idToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case expiresIn = "expires_in"
    }
}

private struct TokenErrorResponse: Decodable {
    let error: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

private struct TokenRefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let idToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case expiresIn = "expires_in"
    }
}
