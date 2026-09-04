import Foundation

/// The user's preferences about the app itself, as opposed to the things they track:
/// where each one is kept and what it starts as. Kept in `UserDefaults` and never in the
/// Library store, which holds only the user's own data (ADR-0005).
@MainActor
@Observable
final class AppSettings {
    private let defaults: UserDefaults

    /// The Appearance in force. System until the user chooses otherwise, and a remembered
    /// value the app no longer knows counts as no choice.
    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Self.appearanceKey) }
    }

    /// The key the Appearance choice is remembered under.
    static let appearanceKey = "appearance"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = defaults.string(forKey: Self.appearanceKey)
            .flatMap(Appearance.init(rawValue:)) ?? .system
    }
}
