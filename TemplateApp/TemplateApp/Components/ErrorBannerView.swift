import SwiftUI

struct ErrorBannerView: View {
    let message: String
    let isVisible: Bool

    var body: some View {
        VStack {
            if isVisible {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.primaryAccent)
                    Text(message)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primaryText)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primaryAccent.opacity(0.4), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2), value: isVisible)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(isVisible)
    }
}

#Preview {
    ErrorBannerView(message: "Something went wrong.", isVisible: true)
        .environment(\.colorScheme, .dark)
}
