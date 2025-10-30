import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var selection: SidebarItem
    @Binding var isVisible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            ForEach(SidebarItem.allCases) { item in
                Button {
                    selection = item
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isVisible = false
                    }
                } label: {
                    Label(item.title, systemImage: item.icon)
                        .font(.headline)
                        .foregroundStyle(selection == item ? .white : .white.opacity(0.75))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(selection == item ? Color(hex: appState.manifest.theme.primaryHex) : Color.clear)
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
                colors: [
                    Color(hex: appState.manifest.theme.primaryHex).opacity(0.85),
                    Color(hex: appState.manifest.theme.primaryHex).opacity(0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appState.manifest.displayName)
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text(appState.manifest.activeEnvironment.rawValue.uppercased())
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

#Preview {
    SidebarView(selection: .constant(.home), isVisible: .constant(true))
        .environmentObject(AppState())
}
