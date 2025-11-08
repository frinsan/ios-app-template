import Foundation

struct UserProfile: Codable, Identifiable {
    let appId: String
    let userId: String
    let email: String?
    let givenName: String?
    let familyName: String?
    let createdAt: String
    let updatedAt: String
    let environment: String?

    var id: String { "\(appId)-\(userId)" }

    var displayName: String {
        if let givenName, let familyName {
            return "\(givenName) \(familyName)"
        }
        if let givenName {
            return givenName
        }
        return email ?? userId
    }
}

struct UserProfileService {
    private let manifest: AppManifest
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(manifest: AppManifest) {
        self.manifest = manifest
    }

    func bootstrapProfile(session: AuthSession) async throws -> UserProfile {
        let payload = BootstrapPayload(
            email: session.user.email,
            givenName: session.user.givenName,
            familyName: session.user.familyName
        )
        return try await send(
            path: "/v1/users/bootstrap",
            method: "POST",
            body: payload,
            session: session
        )
    }

    func fetchProfile(session: AuthSession) async throws -> UserProfile {
        return try await send(path: "/v1/users/me", method: "GET", body: Optional<BootstrapPayload>.none, session: session)
    }

    func deleteAccount(session: AuthSession) async throws {
        let cleanPath = "v1/users/me"
        let url = manifest.baseURL.appendingPathComponent(cleanPath)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(manifest.appId, forHTTPHeaderField: "x-app-id")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.responseError("No response from server")
        }
        guard httpResponse.statusCode < 400 else {
            let message = String(data: data, encoding: .utf8)
            throw APIError.responseError(message ?? "Unable to delete account")
        }
    }

    private func send<Body: Encodable>(
        path: String,
        method: String,
        body: Body?,
        session: AuthSession
    ) async throws -> UserProfile {
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let url = manifest.baseURL.appendingPathComponent(cleanPath)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(manifest.appId, forHTTPHeaderField: "x-app-id")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 400 else {
            let message = String(data: data, encoding: .utf8)
            throw APIError.responseError(message)
        }

        return try decoder.decode(UserProfile.self, from: data)
    }

    private struct BootstrapPayload: Codable {
        let email: String?
        let givenName: String?
        let familyName: String?
    }
}
