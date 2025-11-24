import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appState: AppState
    let items: [SidebarItem]
    @Binding var selection: SidebarItem
    @Binding var isVisible: Bool
    var onSelect: (SidebarItem) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            ForEach(items) { item in
                Button {
                    onSelect(item)
                    selection = selectionForHighlight(item: item)
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isVisible = false
                    }
                } label: {
                    Label(item.title, systemImage: item.icon)
                        .font(.headline)
                        .foregroundStyle(selection == item ? Color.white : Color.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(
                            selection == item
                            ? Color.white.opacity(0.08)
                            : Color.white.opacity(0.02)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(selection == item ? Color.white.opacity(0.2) : Color.clear, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.top, 60)
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 3/255, green: 6/255, blue: 15/255),
                    Color(red: 2/255, green: 8/255, blue: 22/255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private func selectionForHighlight(item: SidebarItem) -> SidebarItem {
        switch item {
        case .terms, .privacy:
            return selection
        default:
            return item
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appState.manifest.displayName)
                .font(.title2.bold())
                .foregroundStyle(titleColor)
            if appState.manifest.activeEnvironment != .prod {
                Text(appState.manifest.activeEnvironment.rawValue.uppercased())
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            }
        }
    }

    private var titleColor: Color {
        if UITraitCollection.current.userInterfaceStyle == .dark {
            return .white
        }
        return Color.white.opacity(0.7)
    }
}

#Preview {
    SidebarView(
        items: [.home, .terms, .privacy, .login],
        selection: .constant(.home),
        isVisible: .constant(true),
        onSelect: { _ in }
    )
        .environmentObject(AppState())
}
