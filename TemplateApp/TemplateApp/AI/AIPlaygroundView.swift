import SwiftUI

struct AIPlaygroundView: View {
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var selectedStyle: RewriteStyle = .clearer
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?

    private let aiService: AIService = AIServiceFactory.make()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                stylePicker

                inputSection

                actionButton

                outputSection

                if let errorMessage {
                    errorBanner(errorMessage)
                }
            }
            .padding()
        }
        .navigationTitle("AI Playground")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Text rewrite (playground)")
                .font(.title2.bold())
            Text("Type some text, pick a style, and let the AI helper produce an alternative version. This is a test screen used to validate the platform's AI plumbing.")
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
        }
    }

    private var stylePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Style")
                .font(.headline)
            Picker("Style", selection: $selectedStyle) {
                ForEach(RewriteStyle.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)

            Text(selectedStyle.description)
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Input")
                .font(.headline)

            TextEditor(text: $inputText)
                .frame(minHeight: 120)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.cardBackground)
                )
        }
    }

    private var actionButton: some View {
        Button {
            Task {
                await runRewrite()
            }
        } label: {
            HStack {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
                Text(isProcessing ? "Rewriting…" : "Rewrite with AI")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.primaryAccent)
            .foregroundStyle(Color.overlayText)
            .cornerRadius(12)
        }
        .disabled(isProcessing)
    }

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Output")
                .font(.headline)

            if outputText.isEmpty {
                Text("Rewritten text will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.dividerColor, lineWidth: 1)
                    )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(outputText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack {
                        Spacer()
                        Button {
                            UIPasteboard.general.string = outputText
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.subheadline)
                        }
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.cardBackground)
                )
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(Color.overlayText)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.errorBackground)
            )
            .padding(.top, 4)
    }

    private func runRewrite() async {
        errorMessage = nil
        isProcessing = true
        defer { isProcessing = false }

        do {
            let result = try await aiService.rewrite(text: inputText, style: selectedStyle)
            await MainActor.run {
                outputText = result
            }
        } catch {
            await MainActor.run {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack {
        AIPlaygroundView()
    }
}
