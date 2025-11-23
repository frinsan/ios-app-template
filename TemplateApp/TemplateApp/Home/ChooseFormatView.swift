import SwiftUI

struct ChooseFormatView: View {
    let presets: [PhotoPreset]
    let onSelectPreset: (PhotoPreset) -> Void

    @State private var showingCustomSize = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                presetSections
                customSection
            }
            .padding()
        }
        .background(Color.appBackground.ignoresSafeArea())
        .sheet(isPresented: $showingCustomSize) {
            NavigationStack {
                CustomSizeView { preset in
                    showingCustomSize = false
                    onSelectPreset(preset)
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Choose Format")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.primaryText)
            Text("Select a popular preset or enter a custom size.")
                .font(.callout)
                .foregroundStyle(Color.secondaryText)
        }
    }

    private var presetSections: some View {
        VStack(alignment: .leading, spacing: 20) {
            presetSection(title: "Visa Presets", items: visaPresets)
            presetSection(title: "Passport Presets", items: passportPresets)
        }
    }

    private func presetSection(title: String, items: [PhotoPreset]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            ForEach(items) { preset in
                Button {
                    onSelectPreset(preset)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.label)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.primaryText)
                            Text("\(preset.widthMM, specifier: "%.0f") x \(preset.heightMM, specifier: "%.0f") mm • \(preset.dpi) DPI")
                                .font(.caption)
                                .foregroundStyle(Color.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.secondaryText)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.dividerColor, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var visaPresets: [PhotoPreset] {
        presets
            .filter { $0.docType == .visa }
            .sorted { $0.country.localizedCaseInsensitiveCompare($1.country) == .orderedAscending }
    }

    private var passportPresets: [PhotoPreset] {
        presets
            .filter { $0.docType == .passport }
            .sorted { $0.country.localizedCaseInsensitiveCompare($1.country) == .orderedAscending }
    }

    private var customSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Size")
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            Button {
                showingCustomSize = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Custom Size…")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.primaryText)
                        Text("Enter width, height, units, and DPI")
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(Color.secondaryText)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.dividerColor, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    NavigationStack {
        ChooseFormatView(presets: PresetLibraryLoader.loadPresets()) { _ in }
    }
}
