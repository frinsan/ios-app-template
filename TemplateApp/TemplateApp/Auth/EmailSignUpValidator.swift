import Foundation

struct EmailSignUpValidator {
    static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let atIndex = trimmed.firstIndex(of: "@"),
              trimmed.distance(from: trimmed.startIndex, to: atIndex) > 0 else {
            return false
        }
        let domainPart = trimmed[trimmed.index(after: atIndex)...]
        return domainPart.contains(".")
    }

    static func isValidUsername(_ username: String) -> Bool {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3, trimmed.count <= 32 else {
            return false
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        return trimmed.rangeOfCharacter(from: allowed.inverted) == nil
    }

    static func isFormValid(email: String, password: String, confirmPassword: String, username: String) -> Bool {
        isValidEmail(email)
            && password.count >= 12
            && !confirmPassword.isEmpty
            && password == confirmPassword
            && isValidUsername(username)
    }
}
