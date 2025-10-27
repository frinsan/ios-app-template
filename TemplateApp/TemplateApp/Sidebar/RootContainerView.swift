import SwiftUI

struct RootContainerView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selection: SidebarItem? = .home

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            detailContent
        }
        .tint(Color(hex: appState.manifest.theme.primaryHex))
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection ?? .home {
        case .home:
            ContentView()
        case .account:
            AccountView()
        case .login:
            LoginView()
        }
    }
}

#Preview {
    RootContainerView()
        .environmentObject(AppState())
}
