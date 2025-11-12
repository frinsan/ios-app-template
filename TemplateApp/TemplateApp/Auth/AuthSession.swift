import Foundation

struct AuthSession: Codable, Identifiable {
    let id: UUID
    let accessToken: String
    let refreshToken: String?
    let idToken: String
    let expiresAt: Date
    let user: AuthenticatedUser

    init(
        id: UUID = UUID(),
        accessToken: String,
        refreshToken: String?,
        idToken: String,
        expiresAt: Date,
        user: AuthenticatedUser
    ) {
        self.id = id
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.expiresAt = expiresAt
        self.user = user
    }

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
