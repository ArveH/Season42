import Foundation

/// The iPhone's Watching Order store until the order moves to iCloud: a `UserDefaults`
/// key, the app's own information read back only by the app (ADR-0021). The key is the one
/// the choice has always been kept under, so an order picked before the store existed is
/// still the one in force after it.
struct UserDefaultsWatchingOrderStore: WatchingOrderStore {
    private let defaults: UserDefaults

    /// The key the choice is remembered under. Not renamed lightly: a new key forgets
    /// every choice already made.
    static let key = "watchingOrder"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func read() -> String? {
        defaults.string(forKey: Self.key)
    }

    func write(_ rawValue: String) {
        defaults.set(rawValue, forKey: Self.key)
    }
}
