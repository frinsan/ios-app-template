import SwiftUI

extension View {
    func lightModeTextColor() -> some View {
        modifier(LightModeTextColorExtensionModifier())
    }

    func themedCTA(accentColor: Color) -> some View {
        modifier(ThemedCTAModifier(accentColor: accentColor))
    }
}

struct ConsistentButtonStyle: ButtonStyle {
    var accentColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.primaryText)
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
    let accentColor: Color

    func body(content: Content) -> some View {
        content
            .font(.headline)
            .foregroundStyle(Color.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
