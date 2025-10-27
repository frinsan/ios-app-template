import Foundation
import SwiftUI

enum SidebarItem: Hashable, CaseIterable, Identifiable {
    case home
    case account
    case login

    var id: String { title }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .account: return "person.circle.fill"
        case .login: return "lock.fill"
        }
    }

    var title: String {
        switch self {
        case .home: return "Home"
        case .account: return "Account"
        case .login: return "Login"
        }
    }

    var color: Color {
        switch self {
        case .home: return .accentColor
        case .account: return .teal
        case .login: return .orange
        }
    }
}
