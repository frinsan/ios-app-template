import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Text(appState.manifest.displayName)
                .font(.largeTitle)
            Text("Environment: \(appState.manifest.activeEnvironment.rawValue)")
                .foregroundStyle(.secondary)
            Spacer()
            Text("Welcome! Hook up API calls and theming here.")
                .font(.headline)
            Spacer()
        }
        .padding()
        .navigationTitle("Home")
        .lightModeTextColor()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
