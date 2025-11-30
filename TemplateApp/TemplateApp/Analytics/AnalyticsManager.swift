import Foundation
import Combine
import UIKit

enum AnalyticsEvent {
    case appOpen
    case screenView(name: String)
    case buttonTap(name: String)
    case error(message: String)

    var type: String {
        switch self {
        case .appOpen: return "appOpen"
        case .screenView: return "screenView"
        case .buttonTap: return "buttonTap"
        case .error: return "error"
        }
    }

    var name: String? {
        switch self {
        case .appOpen: return "app_open"
        case let .screenView(name): return name
        case let .buttonTap(name): return name
        case .error: return nil
        }
    }

    var message: String? {
        switch self {
        case .appOpen, .screenView, .buttonTap: return nil
        case let .error(message): return message
        }
    }
}

final class AnalyticsManager {
    static let shared = AnalyticsManager()

    private var manifest: AppManifest?
    private var accessToken: String?
    private var hasSentAppOpen = false
    private var cancellables = Set<AnyCancellable>()
    private let encoder = JSONEncoder()

    private init() {
        encoder.dateEncodingStrategy = .iso8601
    }

    func configure(with appState: AppState) {
        appState.$manifest
            .receive(on: DispatchQueue.main)
            .sink { [weak self] manifest in
                self?.manifest = manifest
                if !(self?.hasSentAppOpen ?? false) {
                    self?.hasSentAppOpen = true
                    self?.track(.appOpen)
                }
            }
            .store(in: &cancellables)

        appState.$authState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] authState in
                if case let .signedIn(session) = authState {
                    self?.accessToken = session.accessToken
                } else {
                    self?.accessToken = nil
                }
            }
            .store(in: &cancellables)
    }

    func track(_ event: AnalyticsEvent) {
        guard let manifest else { return }
        let payload = AnalyticsPayload(
            appId: manifest.appId,
            environment: manifest.activeEnvironment.rawValue,
            eventType: event.type,
            name: event.name,
            message: event.message,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            device: AnalyticsDeviceInfo.current
        )

        if let data = try? encoder.encode(payload),
           let json = String(data: data, encoding: .utf8) {
            print("[Analytics] \(json)")
        }

        Task {
            await send(payload, manifest: manifest)
        }
    }

    private func send(_ payload: AnalyticsPayload, manifest: AppManifest) async {
        var request = URLRequest(url: manifest.baseURL.appendingPathComponent("/v1/analytics"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(manifest.appId, forHTTPHeaderField: "X-App-Id")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try? encoder.encode(payload)

        do {
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("[Analytics] Failed to send: \(error)")
        }
    }
}

private struct AnalyticsPayload: Codable {
    let appId: String
    let environment: String
    let eventType: String
    let name: String?
    let message: String?
    let timestamp: String
    let device: AnalyticsDeviceInfo
}

private struct AnalyticsDeviceInfo: Codable {
    let model: String
    let os: String
    let appVersion: String

    static var current: AnalyticsDeviceInfo {
        let device = UIDevice.current
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        return AnalyticsDeviceInfo(
            model: device.model,
            os: "\(device.systemName) \(device.systemVersion)",
            appVersion: version
        )
    }
}
