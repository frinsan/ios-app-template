import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?

    var body: some View {
        List(SidebarItem.allCases, selection: $selection) { item in
            Label(item.title, systemImage: item.icon)
                .badge(item == .login ? "Auth" : nil)
        }
        .listStyle(.sidebar)
        .navigationTitle("Menu")
    }
}

#Preview {
    SidebarView(selection: .constant(.home))
}
