import SwiftUI

struct LoadingOverlay: View {
    let isVisible: Bool
    var message: String?

    var body: some View {
        Group {
            if isVisible {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.primaryAccent)
                        if let message {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(Color.primaryText)
                        }
                    }
                    .padding(20)
                    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.dividerColor, lineWidth: 1)
                    )
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: isVisible)
            }
        }
        .allowsHitTesting(isVisible)
    }
}

#Preview {
    LoadingOverlay(isVisible: true, message: "Loading...")
        .environment(\.colorScheme, .dark)
}
