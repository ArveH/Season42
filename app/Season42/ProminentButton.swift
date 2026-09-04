import SwiftUI

extension View {
    /// `.borderedProminent`, with a label that is readable on either value of `AccentColor`
    /// (ADR-0004). The system draws the label white, which is right on the Light value
    /// and unreadable on the Dark one: phosphor green is about 1.3:1 against white. So in
    /// dark drawing the label is dark instead — the accent is left exactly as it is.
    func prominentButtonStyle() -> some View {
        modifier(ProminentButton())
    }
}

private struct ProminentButton: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .buttonStyle(.borderedProminent)
            .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
    }
}
