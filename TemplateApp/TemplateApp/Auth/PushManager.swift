import Foundation
import UserNotifications
import UIKit

final class PushManager: NSObject, ObservableObject {
    static let shared = PushManager()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var deviceToken: String?
    @Published var lastError: String?
    private var deepLinkEnabled: Bool = false
    private var routeHandler: ((String) -> Void)?

    private override init() {
        super.init()
    }

    func configure(deepLinkEnabled: Bool = false, routeHandler: ((String) -> Void)? = nil) {
        self.deepLinkEnabled = deepLinkEnabled
        self.routeHandler = routeHandler
        UNUserNotificationCenter.current().delegate = self
        refreshAuthorizationStatus()
    }

    func refreshAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    func requestAuthorizationAndRegister() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                self.authorizationStatus = granted ? .authorized : .denied
            }
            guard granted else { return }
            registerForRemoteNotifications()
        } catch {
            await MainActor.run { self.lastError = error.localizedDescription }
        }
    }

    func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func handleDeviceToken(_ data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        DispatchQueue.main.async {
            self.deviceToken = token
            self.lastError = nil
        }
    }

    func handleRegistrationError(_ error: Error) {
        DispatchQueue.main.async {
            self.lastError = error.localizedDescription
        }
    }

    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        print("[Push] Received notification: \(userInfo)")
        guard deepLinkEnabled else { return }
        if let route = userInfo["route"] as? String {
            routeHandler?(route)
        }
    }
}

extension PushManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handleRemoteNotification(response.notification.request.content.userInfo)
        completionHandler()
    }
}
