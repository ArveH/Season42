import SwiftUI

extension View {
    /// `.borderedProminent`, with a label that is readable on either value of `AccentColor`
    /// (ADR-0004). The system draws the label white, which is right on the Light value
    /// and unreadable on the Dark one: phosphor green is 1.4:1 against white. So in dark
    /// drawing the label is dark instead — the accent is left exactly as it is, and so is
    /// light drawing.
    func prominentButtonStyle() -> some View {
        modifier(ProminentButton())
    }
}

private struct ProminentButton: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if colorScheme == .dark {
            content
                .buttonStyle(.borderedProminent)
                .foregroundStyle(.black)
        } else {
            content
                .buttonStyle(.borderedProminent)
        }
    }
}
