import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum RewriteStyle: String, CaseIterable, Identifiable {
    case clearer = "Clearer"
    case moreFormal = "More formal"
    case shorter = "Shorter"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .clearer:
            return "Make the text easier to understand without changing the meaning."
        case .moreFormal:
            return "Rewrite in a more professional and formal tone."
        case .shorter:
            return "Keep the key idea but make it more concise."
        }
    }
}

protocol AIService {
    func rewrite(text: String, style: RewriteStyle) async throws -> String
}

enum AIServiceError: Error, LocalizedError {
    case featureUnavailable
    case emptyInput

    var errorDescription: String? {
        switch self {
        case .featureUnavailable:
            return "AI rewriting is not available in this build."
        case .emptyInput:
            return "Type something first so AI has content to work with."
        }
    }
}

/// Default implementation used by the AI Playground.
/// For now this is a lightweight, local transformation so the UI is fully testable
/// even before real on-device LLM APIs are wired in.
struct DefaultAIService: AIService {
    func rewrite(text: String, style: RewriteStyle) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AIServiceError.emptyInput
        }

        // Simple, deterministic transforms to keep behavior predictable.
        switch style {
        case .clearer:
            return clearerVersion(of: trimmed)
        case .moreFormal:
            return moreFormalVersion(of: trimmed)
        case .shorter:
            return shorterVersion(of: trimmed)
        }
    }

    private func clearerVersion(of text: String) -> String {
        """
        Clearer version (placeholder, local transform):

        \(text)
        """
    }

    private func moreFormalVersion(of text: String) -> String {
        """
        More formal version (placeholder, local transform):

        \(text)
        """
    }

    private func shorterVersion(of text: String) -> String {
        let maxLength = 160
        if text.count <= maxLength {
            return """
            Shorter version (placeholder, local transform):

            \(text)
            """
        }

        let index = text.index(text.startIndex, offsetBy: maxLength)
        let shortened = text[..<index]
        return """
        Shorter version (placeholder, local transform):

        \(shortened)…
        """
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
struct AppleOnDeviceAIService: AIService {
    func rewrite(text: String, style: RewriteStyle) async throws -> String {
        // Check that the Apple Intelligence model is actually available on this device.
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw AIServiceError.featureUnavailable
        }

        // High-level instructions that steer the model for this app.
        let instructions = """
        You help people rewrite text according to a requested style.
        - Preserve the original meaning of the input.
        - Respond only with the rewritten text, without any explanation.
        - Use natural language appropriate for the input.
        """

        let session = LanguageModelSession(instructions: instructions)

        let promptHeader: String
        switch style {
        case .clearer:
            promptHeader = "Rewrite the following text to be clearer and easier to understand, without changing its meaning:\n\n"
        case .moreFormal:
            promptHeader = "Rewrite the following text in a more formal and professional tone, without changing its meaning:\n\n"
        case .shorter:
            promptHeader = "Rewrite the following text to be shorter and more concise, while keeping the key idea:\n\n"
        }

        let prompt = promptHeader + text

        // Call the on-device foundation model via the system language model session.
        // Per Apple docs: this suspends while the on-device model generates a response.
        let response: String = try await session.respond(to: prompt)
        // Return the generated text directly; the SDK provides it as the response value.
        return response
    }
}
#endif

enum AIServiceFactory {
    static func make() -> AIService {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *),
           case .available = SystemLanguageModel.default.availability {
            return AppleOnDeviceAIService()
        }
        #endif
        return DefaultAIService()
    }
}
