import SwiftUI
import UIKit

struct ShareButton: View {
    let title: String
    let systemImage: String
    let items: [Any]

    @State private var isPresenting = false

    var body: some View {
        Button(action: { isPresenting = true }) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.semibold))
                .padding(.horizontal, 20)
                .frame(height: 52)
                .frame(maxWidth: .infinity)
                .background(Color.cardBackground, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.dividerColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPresenting) {
            ShareSheet(activityItems: items)
                .ignoresSafeArea()
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
