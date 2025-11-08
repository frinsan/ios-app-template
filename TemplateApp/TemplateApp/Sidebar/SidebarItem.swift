import Foundation
import SwiftUI

enum SidebarItem: Hashable, CaseIterable, Identifiable {
    case home
    case terms
    case privacy
    case account
    case login

    var id: String { title }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .terms: return "doc.text"
        case .privacy: return "hand.raised"
        case .account: return "person.circle.fill"
        case .login: return "lock.fill"
        }
    }

    var title: String {
        switch self {
        case .home: return "Home"
        case .terms: return "Terms of Use"
        case .privacy: return "Privacy Policy"
        case .account: return "Account"
        case .login: return "Sign up or log in"
        }
    }

    var color: Color {
        switch self {
        case .home: return .accentColor
        case .terms: return .indigo
        case .privacy: return .mint
        case .account: return .teal
        case .login: return .orange
        }
    }
}
