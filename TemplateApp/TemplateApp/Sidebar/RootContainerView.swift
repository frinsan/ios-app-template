import SwiftUI

struct RootContainerView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selection: SidebarItem = .home
    @State private var isMenuVisible = false
    @State private var sheetType: LegalSheetType?

    private let drawerWidth: CGFloat = 280
    private var menuItems: [SidebarItem] {
        var items: [SidebarItem] = [.home, .terms, .privacy]
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
            .accentColor(Color(hex: appState.manifest.theme.accentHex))

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
        .sheet(item: $sheetType) { sheet in
            LegalDocumentSheet(title: sheet.title, message: sheet.message)
                .presentationDetents([.fraction(0.85)])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: profileCompletionBinding) { prompt in
            ProfileCompletionSheet(prompt: prompt)
                .presentationDetents([.fraction(0.75)])
                .presentationDragIndicator(.visible)
        }
        .lightModeTextColor()
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .home:
            ContentView()
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
            sheetType = .terms
        case .privacy:
            sheetType = .privacy
        default:
            selection = item
        }
    }

    private func toggleMenu() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isMenuVisible.toggle()
        }
    }

    private var profileCompletionBinding: Binding<ProfileCompletionPrompt?> {
        Binding(
            get: { appState.profileCompletionPrompt },
            set: { appState.profileCompletionPrompt = $0 }
        )
    }
}

private enum LegalSheetType: Identifiable {
    case terms
    case privacy

    var id: String {
        switch self {
        case .terms: return "terms"
        case .privacy: return "privacy"
        }
    }

    var title: String {
        switch self {
        case .terms: return "Terms of Use"
        case .privacy: return "Privacy Policy"
        }
    }

    var message: String {
        switch self {
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

private struct ProfileCompletionSheet: View {
    @EnvironmentObject private var appState: AppState
    let prompt: ProfileCompletionPrompt
    @State private var username: String
    @State private var email: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(prompt: ProfileCompletionPrompt) {
        self.prompt = prompt
        _username = State(initialValue: prompt.currentUsername)
        _email = State(initialValue: prompt.currentEmail)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Add a username and email so we know how to reach you. This only needs to be done once per account.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("Username") {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(isSaving)

                    if let usernameMessage {
                        Text(usernameMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else {
                        Text("Use 3-32 letters, numbers, period, underscore, or dash.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Email") {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()

                    if let emailMessage {
                        Text(emailMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Complete your profile")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!isFormValid || isSaving)
                }
            }
        }
        .interactiveDismissDisabled(true)
    }

    private var trimmedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var usernameMessage: String? {
        guard !trimmedUsername.isEmpty else { return "Username is required." }
        return EmailSignUpValidator.isValidUsername(trimmedUsername)
            ? nil
            : "Use 3-32 letters, numbers, period, underscore, or dash."
    }

    private var emailMessage: String? {
        guard !trimmedEmail.isEmpty else { return "Email is required." }
        return EmailSignUpValidator.isValidEmail(trimmedEmail) ? nil : "Enter a valid email address."
    }

    private var isFormValid: Bool {
        (usernameMessage == nil) && (emailMessage == nil)
    }

    private func save() {
        guard isFormValid else { return }
        errorMessage = nil
        isSaving = true
        Task {
            do {
                try await appState.completeProfile(email: trimmedEmail, username: trimmedUsername)
                await MainActor.run {
                    isSaving = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Unable to save profile. Please try again."
                    isSaving = false
                }
            }
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
