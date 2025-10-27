import Foundation

final class AuthSessionStorage {
    static let shared = AuthSessionStorage()
    private let key = "TemplateApp.AuthSession"

    private init() {}

    func store(_ session: AuthSession) throws {
        let data = try JSONEncoder().encode(session)
        UserDefaults.standard.set(data, forKey: key)
    }

    func load() -> AuthSession? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
