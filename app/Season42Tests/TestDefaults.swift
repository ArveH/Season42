import Foundation
import Testing

/// A `UserDefaults` suite of one test's own, thrown away when the test is done, so a
/// choice made in one test is never the choice another test starts from.
@MainActor
final class TestDefaults {
    let suite: UserDefaults
    private let name: String

    init() throws {
        name = "Season42Tests.\(UUID().uuidString)"
        suite = try #require(UserDefaults(suiteName: name))
    }

    deinit {
        suite.removePersistentDomain(forName: name)
    }
}
