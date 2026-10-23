import Foundation

/// The iPhone's Watching Order store: iCloud's key-value store, so the Watch App lists in
/// the order the user picked on the phone (ADR-0022). The choice is also kept in
/// `UserDefaults`, under the key it was kept under before the move, which does two things:
/// a choice made before the move is still the one in force after it, and the iPhone keeps
/// its choice where no iCloud account is available to the app.
///
/// Where the two disagree, iCloud's wins: it holds the choice last made on any device.
struct ICloudWatchingOrderStore: WatchingOrderStore {
    private let cloud: any KeyValueStore
    private let local: any KeyValueStore

    /// The key the choice is remembered under, in both stores. Not renamed lightly: a new
    /// key forgets every choice already made, and the Watch App reads this one.
    static let key = "watchingOrder"

    init(
        cloud: any KeyValueStore = NSUbiquitousKeyValueStore.default,
        local: any KeyValueStore = UserDefaults.standard
    ) {
        self.cloud = cloud
        self.local = local
    }

    /// iCloud's choice, or the device's where iCloud has none — which it then carries into
    /// iCloud, so a choice made before the move reaches the Watch App without being made
    /// again.
    func read() -> String? {
        if let choice = cloud.string(forKey: Self.key) {
            return choice
        }
        guard let choice = local.string(forKey: Self.key) else { return nil }
        cloud.set(choice, forKey: Self.key)
        return choice
    }

    func write(_ rawValue: String) {
        cloud.set(rawValue, forKey: Self.key)
        local.set(rawValue, forKey: Self.key)
    }
}

/// A store of strings by key: what `UserDefaults` and iCloud's key-value store have in
/// common, so a test can stand a `UserDefaults` suite in for iCloud.
protocol KeyValueStore {
    func string(forKey key: String) -> String?
    func set(_ value: Any?, forKey key: String)
}

extension UserDefaults: KeyValueStore {}
extension NSUbiquitousKeyValueStore: KeyValueStore {}
