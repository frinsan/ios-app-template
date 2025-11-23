import SwiftUI
import AVKit

struct WelcomeView: View {
    @EnvironmentObject private var appState: AppState

    @State private var isAuthenticating = false
    @State private var currentProvider: HostedUIProvider?
    @State private var showMoreOptions = false
    @State private var showEmailSignUp = false
    @State private var showEmailLogin = false
    @State private var activeLegalLink: LegalLink?

    var onSkip: (() -> Void)?

    var body: some View {
        ZStack {
            VideoBackgroundView(videoName: "neuron_loop", fileExtension: "mp4")
                .ignoresSafeArea()
            LinearGradient(
                colors: [
                    Color.black.opacity(0.6),
                    Color.black.opacity(0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                titleBlock
                Spacer()
                buttonStack
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showEmailSignUp) {
            NavigationStack {
                EmailSignUpView()
            }
            .environmentObject(appState)
        }
        .sheet(isPresented: $showEmailLogin) {
            NavigationStack {
                EmailLoginView()
            }
            .environmentObject(appState)
        }
        .sheet(item: $activeLegalLink) { link in
            if let url = link.url(from: appState.manifest) {
                SafariWebView(url: url)
                    .ignoresSafeArea()
            } else {
                NavigationStack {
                    Text("Link not configured yet.")
                        .padding()
                        .navigationTitle(link.title)
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button(action: handleSkip) {
                Text("Skip")
                    .font(.subheadline.bold())
                    .padding(.vertical, 8)
                    .padding(.horizontal, 18)
                    .background(Color.black.opacity(0.25), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            }
            .foregroundStyle(.white)
        }
        .padding(.top, 12)
    }

    private var titleBlock: some View {
        VStack(spacing: 12) {
            Text(appSubtitlePlaceholder)
                .font(.system(size: 18, weight: .light, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.8))
                .multilineTextAlignment(.center)

            Text("Learn & Be Curious Apps")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Let’s build.")
                .font(.system(size: 18, weight: .light, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
    }

    private var appSubtitlePlaceholder: String {
        if !appState.manifest.displayName.isEmpty {
            return appState.manifest.displayName
        }
        return "Your app subtitle goes here"
    }

    private var buttonStack: some View {
        VStack(spacing: 18) {
            PrimaryAuthButton(
                title: "Sign up with Apple",
                systemImage: "applelogo",
                isLoading: isAuthenticating && currentProvider == .apple,
                action: { startLogin(provider: .apple) }
            )

            PrimaryAuthButton(
                title: "Sign up with Google",
                systemImage: "globe",
                isLoading: isAuthenticating && currentProvider == .google,
                action: { startLogin(provider: .google) }
            )

            Button(action: toggleMoreOptions) {
                Text(showMoreOptions ? "Hide options" : "More options")
                    .font(.subheadline.weight(.medium))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 20)
                    .background(Color.white.opacity(showMoreOptions ? 0.25 : 0.18), in: Capsule())
            }
            .foregroundStyle(.white.opacity(0.9))

            if showMoreOptions {
                moreOptionsRow
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            legalText
                .padding(.top, 8)
        }
    }

    private var moreOptionsRow: some View {
        HStack(spacing: 12) {
            SecondaryOptionButton(title: "Sign up with email", systemImage: "envelope") {
                showEmailSignUp = true
            }
            SecondaryOptionButton(title: "Log in with email", systemImage: "person.crop.circle.badge.checkmark") {
                showEmailLogin = true
            }
        }
    }

    private var legalText: some View {
        VStack(spacing: 4) {
            Text("By continuing you agree to the")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))

            HStack(spacing: 6) {
                Button(action: { openLegalLink(.terms) }) {
                    Text("Terms of Service")
                        .font(.caption2.weight(.semibold))
                        .underline()
                }

                Text("and")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))

                Button(action: { openLegalLink(.privacy) }) {
                    Text("Privacy Policy")
                        .font(.caption2.weight(.semibold))
                        .underline()
                }
            }
            .foregroundStyle(.white)
        }
        .multilineTextAlignment(.center)
    }

    private func startLogin(provider: HostedUIProvider) {
        guard case .signedOut = appState.authState else { return }
        currentProvider = provider
        isAuthenticating = true
        Task {
            do {
                let session = try await HostedUILoginController.signIn(provider: provider, manifest: appState.manifest)
                await MainActor.run {
                    appState.handleLoginSuccess(session)
                    isAuthenticating = false
                    currentProvider = nil
                }
            } catch {
                print("[WelcomeView] Login failed: \(error)")
                await MainActor.run {
                    appState.authState = .signedOut
                    isAuthenticating = false
                    currentProvider = nil
                }
            }
        }
    }

    private func toggleMoreOptions() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            showMoreOptions.toggle()
        }
    }

    private func handleSkip() {
        if let onSkip {
            onSkip()
        } else {
            print("[WelcomeView] Skip tapped – hook up to guest flow.")
        }
    }

    private func openLegalLink(_ link: LegalLink) {
        guard link.url(from: appState.manifest) != nil else {
            print("[WelcomeView] \(link.title) URL missing.")
            return
        }
        activeLegalLink = link
    }
}

// MARK: - Supporting Views

private struct PrimaryAuthButton: View {
    let title: String
    let systemImage: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                Text(title)
                    .font(.headline.weight(.semibold))
                Spacer()
                if isLoading {
                    ProgressView()
                        .tint(Color.primaryText)
                } else {
                    Image(systemName: "arrow.forward.circle.fill")
                        .font(.title3)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(height: 58)
            .background(Color.white.opacity(0.15), in: Capsule())
        }
        .disabled(isLoading)
    }
}

private struct SecondaryOptionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.headline)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Color.primaryText)
            .padding(.horizontal, 18)
            .frame(height: 46)
            .background(Color.cardBackground.opacity(0.3), in: Capsule())
        }
    }
}

// MARK: - Video Background

private struct VideoBackgroundView: UIViewRepresentable {
    let videoName: String
    let fileExtension: String

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        LoopingPlayerUIView(videoName: videoName, fileExtension: fileExtension)
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) { }
}

private final class LoopingPlayerUIView: UIView {
    private var playerLooper: AVPlayerLooper?
    private var queuePlayer: AVQueuePlayer?

    init(videoName: String, fileExtension: String) {
        super.init(frame: .zero)
        guard let url = Bundle.main.url(forResource: videoName, withExtension: fileExtension) else {
            return
        }

        let playerItem = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(playerItem: playerItem)
        queuePlayer.isMuted = true
        queuePlayer.play()

        let playerLayer = AVPlayerLayer(player: queuePlayer)
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)

        self.queuePlayer = queuePlayer
        self.playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.sublayers?.forEach { $0.frame = bounds }
    }
}

// MARK: - Legal Links

private enum LegalLink: Identifiable {
    case terms
    case privacy

    var id: String { title }

    var title: String {
        switch self {
        case .terms: return "Terms of Service"
        case .privacy: return "Privacy Policy"
        }
    }

    func url(from manifest: AppManifest) -> URL? {
        switch self {
        case .terms:
            return manifest.legal?.termsUrl
        case .privacy:
            return manifest.legal?.privacyUrl
        }
    }
}

#Preview {
    WelcomeView(onSkip: { })
        .environmentObject(AppState())
}
