import Foundation

struct ProfileOverrides {
    var email: String?
    var username: String?
    var givenName: String?
    var familyName: String?
}

struct ProfileCompletionPrompt: Identifiable, Equatable {
    let id = UUID()
    let missingEmail: Bool
    let missingUsername: Bool
    let currentEmail: String
    let currentUsername: String
}

extension String {
    var trimmedOrNil: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
