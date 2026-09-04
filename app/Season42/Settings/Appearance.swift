import SwiftUI

/// How the app draws: light, dark, or however the device is drawing — the user's own
/// choice, made on the Settings tab. The raw value is what the choice is remembered as
/// between launches, so a case is not renamed lightly.
enum Appearance: String, CaseIterable {
    /// Follow the device. The default, so nothing changes for anyone who never chooses.
    case system

    case light

    case dark

    /// What the Settings control calls it.
    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// What to hand `preferredColorScheme` at the root: nil for System, so the device
    /// decides, and a fixed scheme for the other two, so no screen is left drawing the
    /// other way.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
