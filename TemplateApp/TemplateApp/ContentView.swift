import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text(appState.manifest.displayName)
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.primaryText)
                    Text("Environment: \(appState.manifest.activeEnvironment.rawValue.uppercased())")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                }

                Spacer()

                VStack(spacing: 12) {
                    Text("Welcome! Hook up API calls and theming here.")
                        .font(.headline)
                        .foregroundStyle(Color.primaryText)
                    Divider()
                        .background(Color.dividerColor)
                    Text("Use the sidebar to explore legal pages, account settings, and login flows.")
                        .font(.callout)
                        .foregroundStyle(Color.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.dividerColor, lineWidth: 1)
                )

                Spacer()
            }
            .padding()
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
