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

    static func isFormValid(email: String, password: String, confirmPassword: String) -> Bool {
        isValidEmail(email)
            && !password.isEmpty
            && !confirmPassword.isEmpty
            && password == confirmPassword
    }
}
