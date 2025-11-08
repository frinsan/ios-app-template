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
    @Environment(\.colorScheme) private var colorScheme
    var accentColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(colorScheme == .light ? .black : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(backgroundColor.opacity(configuration.isPressed ? 0.85 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }

    private var backgroundColor: Color {
        colorScheme == .light ? accentColor : Color(UIColor.systemGray4)
    }
}

private struct LightModeTextColorModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if colorScheme == .light {
            content.foregroundColor(.black)
        } else {
            content
        }
    }

    static func tintColor(for style: ColorScheme) -> Color {
        style == .light ? .black : Color(UIColor.systemGreen)
    }
}

private struct LightModeTextColorExtensionModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .modifier(LightModeTextColorModifier())
            .tint(LightModeTextColorModifier.tintColor(for: colorScheme))
    }
}

private struct ThemedCTAModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let accentColor: Color

    func body(content: Content) -> some View {
        content
            .font(.headline)
            .foregroundColor(colorScheme == .light ? .black : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var backgroundColor: Color {
        colorScheme == .light ? accentColor : Color(UIColor.systemGray4)
    }
}
