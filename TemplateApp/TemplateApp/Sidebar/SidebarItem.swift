import Foundation
import SwiftUI

enum SidebarItem: Hashable, CaseIterable, Identifiable {
    case home
    case settings
    case aiPlayground
    case terms
    case privacy
    case account
    case login

    var id: String { title }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .settings: return "gearshape.fill"
        case .aiPlayground: return "sparkles"
        case .terms: return "doc.text"
        case .privacy: return "hand.raised"
        case .account: return "person.circle.fill"
        case .login: return "lock.fill"
        }
    }

    var title: String {
        switch self {
        case .home: return "Home"
        case .settings: return "Settings"
        case .aiPlayground: return "AI Playground"
        case .terms: return "Terms of Use"
        case .privacy: return "Privacy Policy"
        case .account: return "Account"
        case .login: return "Sign up or log in"
        }
    }

    var color: Color {
        switch self {
        case .home: return .accentColor
        case .settings: return .blue
        case .aiPlayground: return .purple
        case .terms: return .indigo
        case .privacy: return .mint
        case .account: return .teal
        case .login: return .orange
        }
    }
}
