@testable import Season42

/// A Watching Order store held in memory, one per test, so a choice made in one test is
/// never the choice another test starts from. Two listings handed the same one share a
/// choice the way two launches of the app share theirs.
final class TestOrderStore: WatchingOrderStore {
    private var stored: String?

    func read() -> String? {
        stored
    }

    func write(_ rawValue: String) {
        stored = rawValue
    }
}
