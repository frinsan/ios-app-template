import Foundation
import StoreKit

final class RatePromptManager {
    static let shared = RatePromptManager()
    private let lastPromptKey = "RatePromptManager.lastPrompt"
    private let minInterval: TimeInterval = 60 * 60 * 24 // once per day

    private init() {}

    func requestReviewIfAllowed() {
        guard canPrompt else { return }
        DispatchQueue.main.async {
            if let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) {
                SKStoreReviewController.requestReview(in: scene)
                self.updateLastPrompt()
            }
        }
    }

    private var canPrompt: Bool {
        guard let last = UserDefaults.standard.object(forKey: lastPromptKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(last) > minInterval
    }

    private func updateLastPrompt() {
        UserDefaults.standard.set(Date(), forKey: lastPromptKey)
    }
}
