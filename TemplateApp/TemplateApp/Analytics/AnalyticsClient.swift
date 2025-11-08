import Foundation

enum AnalyticsEventName: String {
    case emailSignupSubmitted
    case emailSignupResentCode
    case emailSignupConfirmed
    case emailLoginAttempt
    case emailPasswordResetRequested
    case emailPasswordResetConfirmed
    case accountDeleted
}

struct AnalyticsEvent {
    let name: AnalyticsEventName
    let properties: [String: String]?
    let timestamp: Date
}

final class AnalyticsClient {
    static let shared = AnalyticsClient()
    private let queue = DispatchQueue(label: "AnalyticsClient")

    private init() {}

    func track(_ name: AnalyticsEventName, properties: [String: String]? = nil) {
        let event = AnalyticsEvent(name: name, properties: properties, timestamp: Date())
        queue.async {
            #if DEBUG
            print("[Analytics]", event.name.rawValue, event.properties ?? [:])
            #endif
            // Hook for downstream integrations (Segment, Pinpoint, etc.)
        }
    }
}
