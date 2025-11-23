import SwiftUI

struct PassportHomeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                actionButtons
            }
            .padding()
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.appBackground.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Passport Photo Maker")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.primaryText)
            Text("Passport, visa, and custom sizes")
                .font(.headline)
                .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionButtons: some View {
        VStack(spacing: 16) {
            NavigationLink {
                PhotoFlowView()
            } label: {
                PrimaryCTAView(
                    title: "Start New Photo",
                    subtitle: "Capture or upload a new image",
                    icon: "camera.fill"
                )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct PrimaryCTAView: View {
    let title: String
    let subtitle: String
    let icon: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(buttonTextColor)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(buttonTextColor.opacity(0.8))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.headline)
                .foregroundStyle(buttonTextColor.opacity(0.8))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.primaryAccent)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    private var buttonTextColor: Color {
        if colorScheme == .dark {
            return Color(red: 30 / 255, green: 41 / 255, blue: 59 / 255)
        }
        return Color.primaryText
    }
}

#Preview {
    NavigationStack {
        PassportHomeView()
            .environmentObject(AppState())
    }
}
