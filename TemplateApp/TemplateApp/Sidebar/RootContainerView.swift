import SwiftUI

struct RootContainerView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selection: SidebarItem = .home
    @State private var isMenuVisible = false

    private let drawerWidth: CGFloat = 280

    var body: some View {
        ZStack(alignment: .leading) {
            NavigationStack {
                detailContent
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: toggleMenu) {
                                Image(systemName: "line.horizontal.3")
                                    .imageScale(.large)
                            }
                        }
                    }
                    .animation(.easeInOut, value: selection)
            }
            .accentColor(Color(hex: appState.manifest.theme.accentHex))

            if isMenuVisible {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { toggleMenu() }
                    .transition(.opacity)
            }

            SidebarView(selection: $selection, isVisible: $isMenuVisible)
                .frame(width: drawerWidth)
                .offset(x: isMenuVisible ? 0 : -drawerWidth - 16)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 4, y: 0)
                .animation(.easeInOut(duration: 0.25), value: isMenuVisible)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .home:
            ContentView()
        case .account:
            AccountView()
        case .login:
            LoginView()
        }
    }

    private func toggleMenu() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isMenuVisible.toggle()
        }
    }
}

#Preview {
    RootContainerView()
        .environmentObject(AppState())
}
