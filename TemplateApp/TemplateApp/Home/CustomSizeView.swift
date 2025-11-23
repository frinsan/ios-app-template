import SwiftUI

struct CustomSizeView: View {
    enum Unit: String, CaseIterable, Identifiable {
        case millimeters
        case inches

        var id: String { rawValue }

        var label: String {
            switch self {
            case .millimeters: return "Millimeters"
            case .inches: return "Inches"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    @State private var width: String = ""
    @State private var height: String = ""
    @State private var unit: Unit = .millimeters
    @State private var dpi: String = "300"
    @State private var showError = false

    let onSubmit: (PhotoPreset) -> Void

    var body: some View {
        Form {
            Section("Dimensions") {
                TextField("Width", text: $width)
                    .keyboardType(.decimalPad)
                TextField("Height", text: $height)
                    .keyboardType(.decimalPad)
                Picker("Units", selection: $unit) {
                    ForEach(Unit.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
            }

            Section("Resolution") {
                TextField("DPI", text: $dpi)
                    .keyboardType(.numberPad)
            }

            Section {
                Button(action: submit) {
                    Text("Use This Size")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.primaryAccent)
            }
        }
        .navigationTitle("Custom Size")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Invalid Input", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please enter valid numerical values for width, height, and DPI.")
        }
    }

    private func submit() {
        guard
            let widthValue = Double(width.replacingOccurrences(of: ",", with: ".")),
            let heightValue = Double(height.replacingOccurrences(of: ",", with: ".")),
            let dpiValue = Int(dpi), dpiValue > 0,
            widthValue > 0, heightValue > 0
        else {
            showError = true
            return
        }

        let widthMM: Double
        let heightMM: Double

        switch unit {
        case .millimeters:
            widthMM = widthValue
            heightMM = heightValue
        case .inches:
            widthMM = widthValue * 25.4
            heightMM = heightValue * 25.4
        }

        let preset = PhotoPreset(
            id: "custom",
            country: "Custom",
            label: "Custom Size",
            docType: .passport,
            widthMM: widthMM,
            heightMM: heightMM,
            dpi: dpiValue,
            notes: nil
        )

        onSubmit(preset)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        CustomSizeView { _ in }
    }
}
