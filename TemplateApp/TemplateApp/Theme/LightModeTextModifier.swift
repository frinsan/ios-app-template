import SwiftUI

extension View {
    func lightModeTextColor() -> some View {
        modifier(LightModeTextColorExtensionModifier())
    }

    func themedCTA(accentColor: Color, prefersSoftDarkText: Bool = false) -> some View {
        modifier(ThemedCTAModifier(accentColor: accentColor, prefersSoftDarkText: prefersSoftDarkText))
    }
}

struct ConsistentButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    var accentColor: Color
    var prefersSoftDarkText: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(labelColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(
                accentColor.opacity(configuration.isPressed ? 0.85 : 1),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }

    private var labelColor: Color {
        if prefersSoftDarkText, colorScheme == .dark {
            return Color(red: 30 / 255, green: 41 / 255, blue: 59 / 255)
        }
        return Color.primaryText
    }
}

private struct LightModeTextColorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(Color.primaryText)
    }
}

private struct LightModeTextColorExtensionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .modifier(LightModeTextColorModifier())
            .tint(Color.primaryAccent)
    }
}

private struct ThemedCTAModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let accentColor: Color
    var prefersSoftDarkText: Bool

    func body(content: Content) -> some View {
        content
            .font(.headline)
            .foregroundStyle(labelColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var labelColor: Color {
        if prefersSoftDarkText, colorScheme == .dark {
            return Color(red: 30 / 255, green: 41 / 255, blue: 59 / 255)
        }
        return Color.primaryText
    }
}
