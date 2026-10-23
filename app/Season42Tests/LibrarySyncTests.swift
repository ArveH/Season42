import Foundation
import SwiftData
import Testing
@testable import Season42

/// Where the Library syncs (ADR-0022): the app's own store to the user's private CloudKit
/// database, in the container the Watch App shares, and no other store anywhere. A test's
/// store that synced would push throwaway data into the user's iCloud.
@MainActor
struct LibrarySyncTests {
    @Test func theAppsOwnStoreSyncsToTheContainerTheWatchAppShares() {
        let configuration = Library.storeConfiguration(at: nil)

        #expect(configuration.cloudKitContainerIdentifier == "iCloud.com.season42.app")
    }

    @Test func aStoreAtAnExplicitLocationNeverSyncs() throws {
        let url = try temporaryStoreDirectory().appending(path: "Library.store")

        #expect(Library.storeConfiguration(at: url).cloudKitContainerIdentifier == nil)
        #expect(try Library.container(at: url).configurations.allSatisfy {
            $0.cloudKitContainerIdentifier == nil
        })
    }

    @Test func anInMemoryStoreNeverSyncs() throws {
        #expect(try Library.inMemoryContainer().configurations.allSatisfy {
            $0.cloudKitContainerIdentifier == nil
        })
    }

    /// What CloudKit imports is written to the store behind the Library's back, by a context
    /// of its own, and announced with a remote-change notification. A Library that didn't
    /// re-read on it showed the other device's changes only after a relaunch.
    @Test func aChangeSyncedInFromAnotherDeviceShowsWithoutARelaunch() throws {
        let url = try temporaryStoreDirectory().appending(path: "Library.store")
        let library = Library(container: try Library.container(at: url))
        let importer = Library(container: try Library.container(at: url))
        try importer.addTrackedSeries(
            title: "Severance",
            seasons: Seasons(episodeCounts: [9]),
            status: .watching
        )

        NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)

        #expect(library.trackedSeries.map(\.title) == ["Severance"])
    }
}
