import Foundation

struct PushRegisterPayload: Codable {
    let token: String
    let platform: String
}

struct PushTestPayload: Codable {
    let message: String?
}

struct PushService {
    private let manifest: AppManifest
    private let encoder = JSONEncoder()

    init(manifest: AppManifest) {
        self.manifest = manifest
    }

    func register(token: String, session: AuthSession) async throws {
        try await send(path: "/v1/push/register", method: "POST", payload: PushRegisterPayload(token: token, platform: "ios"), session: session)
    }

    func unregister(token: String, session: AuthSession) async throws {
        try await send(path: "/v1/push/register", method: "DELETE", payload: PushRegisterPayload(token: token, platform: "ios"), session: session)
    }

    func sendTest(message: String? = nil, session: AuthSession) async throws {
        try await send(path: "/v1/push/test", method: "POST", payload: PushTestPayload(message: message), session: session)
    }

    private func send<Body: Encodable>(path: String, method: String, payload: Body, session: AuthSession) async throws {
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let url = manifest.baseURL.appendingPathComponent(cleanPath)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(manifest.appId, forHTTPHeaderField: "x-app-id")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            let message = String(data: data, encoding: .utf8)
            throw APIError.responseError(message: message ?? "Unable to register push token", code: nil)
        }
    }
}
