import Foundation

struct AuthSession: Codable, Identifiable {
    let id = UUID()
    let accessToken: String
    let refreshToken: String?
    let idToken: String
    let expiresAt: Date
    let user: AuthenticatedUser

    var isExpired: Bool {
        Date() >= expiresAt
    }
}

struct AuthenticatedUser: Codable {
    let subject: String
    let email: String?
    let givenName: String?
    let familyName: String?
}
