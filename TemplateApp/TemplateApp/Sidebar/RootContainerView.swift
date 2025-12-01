import SwiftUI

struct RootContainerView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selection: SidebarItem = .home
    @State private var isMenuVisible = false
    @State private var legalSheet: LegalSheet?

    private let drawerWidth: CGFloat = 280
    private var menuItems: [SidebarItem] {
        var items: [SidebarItem] = [.home]

        if appState.manifest.features.aiPlayground {
            items.append(.aiPlayground)
        }

        items.append(contentsOf: [.terms, .privacy])

        if case .signedIn = appState.authState {
            items.append(.account)
        } else {
            items.append(.login)
        }
        return items
    }

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
            .accentColor(.primaryAccent)

            if isMenuVisible {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { toggleMenu() }
                    .transition(.opacity)
            }

            SidebarView(
                items: menuItems,
                selection: $selection,
                isVisible: $isMenuVisible,
                onSelect: handleSidebarSelection
            )
                .frame(width: drawerWidth)
                .offset(x: isMenuVisible ? 0 : -drawerWidth - 16)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 4, y: 0)
                .animation(.easeInOut(duration: 0.25), value: isMenuVisible)
        }
        .onChange(of: appState.authState) { _, newValue in
            if !menuItems.contains(selection) {
                selection = menuItems.first ?? .home
            } else if selection == .login, case .signedIn = newValue {
                selection = .home
            }
        }
        .onChange(of: appState.latestLoginSuccessID) { _, _ in
            selection = .home
            isMenuVisible = false
        }
        .onChange(of: appState.pendingRoute) { _, newValue in
            guard let route = newValue else { return }
            handleRoute(route)
            appState.pendingRoute = nil
        }
        .sheet(item: $legalSheet) { sheet in
            if let url = sheet.url {
                SafariWebView(url: url)
                    .ignoresSafeArea()
            } else {
                LegalDocumentSheet(title: sheet.title, message: sheet.placeholderMessage)
                    .presentationDetents([.fraction(0.85)])
                    .presentationDragIndicator(.visible)
            }
        }
        .lightModeTextColor()
        .overlay(
            Group {
                if appState.manifest.features.loadingOverlay {
                    LoadingOverlay(isVisible: appState.isLoading, message: appState.loadingMessage)
                }
                if appState.manifest.features.errorBanner, let message = appState.errorBannerMessage {
                    ErrorBannerView(message: message, isVisible: appState.isErrorBannerVisible)
                }
            }
        )
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .home:
            ContentView()
        case .aiPlayground:
            AIPlaygroundView()
        case .terms, .privacy:
            ContentView()
        case .account:
            AccountView()
        case .login:
            LoginView()
        }
    }

    private func handleSidebarSelection(_ item: SidebarItem) {
        switch item {
        case .terms:
            legalSheet = LegalSheet(
                document: .terms,
                url: appState.manifest.legal?.termsUrl
            )
        case .privacy:
            legalSheet = LegalSheet(
                document: .privacy,
                url: appState.manifest.legal?.privacyUrl
            )
        default:
            selection = item
        }
    }

    private func handleRoute(_ route: String) {
        // Only supporting home for now; fallback is home.
        selection = .home
        withAnimation(.easeInOut(duration: 0.2)) {
            isMenuVisible = false
        }
    }

    private func toggleMenu() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isMenuVisible.toggle()
        }
    }
}

private struct LegalSheet: Identifiable {
    enum Document {
        case terms
        case privacy
    }

    let document: Document
    let url: URL?

    var id: String {
        switch document {
        case .terms: return "terms"
        case .privacy: return "privacy"
        }
    }

    var title: String {
        switch document {
        case .terms: return "Terms of Use"
        case .privacy: return "Privacy Policy"
        }
    }

    var placeholderMessage: String {
        switch document {
        case .terms:
            return "Placeholder content for Terms of Use. Replace this with your hosted web page."
        case .privacy:
            return "Placeholder content for Privacy Policy. Replace this with your hosted web page."
        }
    }
}

private struct LegalDocumentSheet: View {
    let title: String
    let message: String

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(message)
                    .multilineTextAlignment(.leading)
                    .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    RootContainerView()
        .environmentObject(AppState())
}

#Preview("Legal Document Sheet") {
    LegalDocumentSheet(
        title: "Terms of Use",
        message: "Detailed terms go here. Replace this placeholder text with the hosted webpage contents."
    )
}
