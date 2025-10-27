import AuthenticationServices
import Foundation
import SwiftUI
import UIKit

enum HostedUIProvider: String {
    case apple
    case google

    var displayName: String {
        rawValue.capitalized
    }
}

enum HostedUILoginError: Error {
    case invalidConfiguration
    case cancelled
    case missingCallback
    case tokenExchangeFailed
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
        guard let authUrl = URL(string: "https://\(domain)/oauth2/authorize?client_id=\(clientId)&response_type=code&identity_provider=\(provider.rawValue)&redirect_uri=\(redirectUri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirectUri)&scope=openid%20email%20profile") else {
            throw HostedUILoginError.invalidConfiguration
        }

        let callbackURL = try await presentHostedUI(url: authUrl, callbackScheme: scheme)
        return try await exchangeCode(callbackURL: callbackURL, clientId: clientId, redirectUri: redirectUri, region: region)
    }

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

    private static func exchangeCode(callbackURL: URL, clientId: String, redirectUri: String, region: String) async throws -> AuthSession {
        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw HostedUILoginError.tokenExchangeFailed
        }

        var request = URLRequest(url: URL(string: "https://cognito-idp.\(region).amazonaws.com/oauth2/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "grant_type=authorization_code&code=\(code)&client_id=\(clientId)&redirect_uri=\(redirectUri)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
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

    private static func decodeJWTClaims(_ token: String) throws -> [String: Any] {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return [:] }
        var body = parts[1]
        let requiredLength = ((body.count + 3) / 4) * 4
        body.append(String(repeating: "=", count: requiredLength - body.count))
        guard let data = Data(base64Encoded: String(body)) else { return [:] }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json ?? [:]
    }
}

private struct HostedUIPresentationAnchor: ASWebAuthenticationPresentationContextProviding {
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
