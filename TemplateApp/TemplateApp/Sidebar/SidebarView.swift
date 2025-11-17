import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appState: AppState
    let items: [SidebarItem]
    @Binding var selection: SidebarItem
    @Binding var isVisible: Bool
    var onSelect: (SidebarItem) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
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
                        .foregroundStyle(selection == item ? Color.primaryText : Color.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            selection == item
                            ? Color.primaryAccent.opacity(0.18)
                            : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.top, 60)
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            LinearGradient(
                colors: [Color.cardBackground, Color.appBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
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
                .foregroundStyle(Color.primaryText)
            Text(appState.manifest.activeEnvironment.rawValue.uppercased())
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
        }
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
