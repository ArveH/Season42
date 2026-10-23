import Foundation
import Testing
@testable import Season42

/// The iPhone's Watching Order store: iCloud's key-value store, so the Watch App lists in
/// the order the user picked on the phone (ADR-0022), with the `UserDefaults` key the choice
/// was kept under before that still read, so a choice made before the move carries over.
/// Each test stands a suite of its own in for iCloud's key-value store.
@MainActor
struct WatchingOrderStoreTests {
    @Test func aChoiceMadeBeforeTheMoveToICloudIsStillInForce() throws {
        let cloud = try TestDefaults()
        let local = try TestDefaults()
        local.suite.set("title", forKey: "watchingOrder")

        let listing = WatchingListing(
            library: try Library.inMemory(),
            orderStore: ICloudWatchingOrderStore(cloud: cloud.suite, local: local.suite)
        )

        #expect(listing.order == .title)
    }

    @Test func readingTheChoiceNeverWritesToICloud() throws {
        let cloud = try TestDefaults()
        let local = try TestDefaults()
        local.suite.set("title", forKey: "watchingOrder")

        _ = WatchingListing(
            library: try Library.inMemory(),
            orderStore: ICloudWatchingOrderStore(cloud: cloud.suite, local: local.suite)
        )

        #expect(cloud.suite.string(forKey: "watchingOrder") == nil)
    }

    @Test func aChoiceIsKeptInICloud() throws {
        let cloud = try TestDefaults()
        let local = try TestDefaults()
        let listing = WatchingListing(
            library: try Library.inMemory(),
            orderStore: ICloudWatchingOrderStore(cloud: cloud.suite, local: local.suite)
        )

        listing.order = .title

        #expect(cloud.suite.string(forKey: "watchingOrder") == "title")
    }

    @Test func aChoiceIsKeptOnTheDeviceTooForWhenThereIsNoICloud() throws {
        let cloud = try TestDefaults()
        let local = try TestDefaults()
        let listing = WatchingListing(
            library: try Library.inMemory(),
            orderStore: ICloudWatchingOrderStore(cloud: cloud.suite, local: local.suite)
        )

        listing.order = .title

        #expect(local.suite.string(forKey: "watchingOrder") == "title")
    }

    @Test func aChoiceMadeOnAnotherDeviceWinsOverThisDevicesEarlierOne() throws {
        let cloud = try TestDefaults()
        let local = try TestDefaults()
        cloud.suite.set("title", forKey: "watchingOrder")
        local.suite.set("lastWatched", forKey: "watchingOrder")

        let listing = WatchingListing(
            library: try Library.inMemory(),
            orderStore: ICloudWatchingOrderStore(cloud: cloud.suite, local: local.suite)
        )

        #expect(listing.order == .title)
    }
}
