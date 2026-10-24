import Foundation
import Observation
import SwiftData
import Testing
@testable import Season42

/// A row already on screen when iCloud changes its entry (#149). A second Library on the same
/// store stands in for CloudKit's import: it writes behind the first Library's back, and the
/// remote-change notification is posted by hand, as in `LibrarySyncTests`.
///
/// Two questions, asked apart so a failure says which one went wrong:
/// - is the changed value there at all, on the object the Library hands out after the sync?
/// - is a row that read that value off the object told it changed? A row reads its model's
///   fields, not the Library's listings, so that is the read the probe makes.
@MainActor
struct SyncedRowRedrawTests {
    private struct Devices {
        let thisPhone: Library
        let otherDevice: Library
    }

    private func twoDevicesOnOneStore() throws -> Devices {
        let url = try temporaryStoreDirectory().appending(path: "Library.store")
        return Devices(
            thisPhone: Library(container: try Library.container(at: url)),
            otherDevice: Library(container: try Library.container(at: url))
        )
    }

    private func syncLands() {
        NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
    }

    private func seriesOnTheOtherDevice(_ devices: Devices) throws -> TrackedSeries {
        try #require(devices.otherDevice.trackedSeries.first { $0.title == "Severance" })
    }

    // MARK: - An episode marked watched on another device

    @Test func anEpisodeWatchedElsewhereIsOnTheSeriesAfterTheSync() throws {
        let devices = try twoDevicesOnOneStore()
        try devices.thisPhone.addTrackedSeries(
            title: "Severance", seasons: Seasons(episodeCounts: [9]), status: .watching
        )
        syncLands()
        devices.otherDevice.markNextEpisodeWatched(try seriesOnTheOtherDevice(devices))

        syncLands()

        let onScreen = try #require(devices.thisPhone.trackedSeries.first)
        #expect(onScreen.position == Position(season: 1, episode: 1))
    }

    @Test func aRowShowingTheSeriesIsToldWhenAnEpisodeIsWatchedElsewhere() throws {
        let devices = try twoDevicesOnOneStore()
        try devices.thisPhone.addTrackedSeries(
            title: "Severance", seasons: Seasons(episodeCounts: [9]), status: .watching
        )
        syncLands()
        let onScreen = try #require(devices.thisPhone.trackedSeries.first)
        let probe = ObservationProbe()
        withObservationTracking {
            _ = onScreen.position
        } onChange: {
            probe.tell()
        }

        devices.otherDevice.markNextEpisodeWatched(try seriesOnTheOtherDevice(devices))
        syncLands()

        // The re-read hands back the very object the row holds, so the row is not rebuilt
        // with a new one either — it is told through this object or not at all.
        #expect(devices.thisPhone.trackedSeries.first === onScreen)
        #expect(probe.wasTold)
    }

    // MARK: - A Streaming Service linked on another device

    @Test func aServiceLinkedElsewhereIsOnTheSeriesAfterTheSync() throws {
        let devices = try twoDevicesOnOneStore()
        try devices.thisPhone.addTrackedSeries(
            title: "Severance", seasons: Seasons(episodeCounts: [9]), status: .watching
        )
        syncLands()
        let service = try devices.otherDevice.addStreamingService(name: "Apple TV+")
        try devices.otherDevice.edit(
            try seriesOnTheOtherDevice(devices),
            title: "Severance",
            seasons: Seasons(episodeCounts: [9]),
            status: .watching,
            streamingService: service
        )

        syncLands()

        let onScreen = try #require(devices.thisPhone.trackedSeries.first)
        #expect(onScreen.streamingService?.name == "Apple TV+")
    }

    @Test func aRowShowingTheSeriesIsToldWhenAServiceIsLinkedElsewhere() throws {
        let devices = try twoDevicesOnOneStore()
        try devices.thisPhone.addTrackedSeries(
            title: "Severance", seasons: Seasons(episodeCounts: [9]), status: .watching
        )
        syncLands()
        let onScreen = try #require(devices.thisPhone.trackedSeries.first)
        let probe = ObservationProbe()
        withObservationTracking {
            _ = onScreen.streamingService?.logo
        } onChange: {
            probe.tell()
        }

        let service = try devices.otherDevice.addStreamingService(name: "Apple TV+")
        try devices.otherDevice.edit(
            try seriesOnTheOtherDevice(devices),
            title: "Severance",
            seasons: Seasons(episodeCounts: [9]),
            status: .watching,
            streamingService: service
        )
        syncLands()

        #expect(probe.wasTold)
    }
}
