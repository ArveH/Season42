import Foundation
import Testing
@testable import Season42

/// The iPhone's Watching Order store: where the choice is kept until it moves to iCloud.
/// It keeps the key the choice has always been kept under, so an order picked before the
/// store existed is still the order in force after it.
@MainActor
struct WatchingOrderStoreTests {
    @Test func aChoiceMadeBeforeTheStoreExistedIsStillInForce() throws {
        let defaults = try TestDefaults()
        defaults.suite.set("title", forKey: "watchingOrder")

        let listing = WatchingListing(
            library: try Library.inMemory(),
            orderStore: UserDefaultsWatchingOrderStore(defaults: defaults.suite)
        )

        #expect(listing.order == .title)
    }

    @Test func aChoiceIsWrittenUnderTheKeyItHasAlwaysHad() throws {
        let defaults = try TestDefaults()
        let listing = WatchingListing(
            library: try Library.inMemory(),
            orderStore: UserDefaultsWatchingOrderStore(defaults: defaults.suite)
        )

        listing.order = .title

        #expect(defaults.suite.string(forKey: "watchingOrder") == "title")
    }
}
