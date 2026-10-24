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
/// - is a row that read that value told it changed? A list reads the Library's listing and
///   hands each row its model; the row reads the model's fields. The probe reads both, the way
///   a list and its row do together, because after a sync the row is told by being handed a
///   new object (ADR-0024).
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
            _ = devices.thisPhone.trackedSeries.first?.position
        } onChange: {
            probe.tell()
        }

        devices.otherDevice.markNextEpisodeWatched(try seriesOnTheOtherDevice(devices))
        syncLands()

        // A merged change never goes through the object the row holds, so the re-read hands
        // the row a new object instead, and SwiftUI draws it again.
        #expect(devices.thisPhone.trackedSeries.first !== onScreen)
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
        let probe = ObservationProbe()
        withObservationTracking {
            _ = devices.thisPhone.trackedSeries.first?.streamingService?.logo
        } onChange: {
            probe.tell()
        }
        let onScreen = try #require(devices.thisPhone.trackedSeries.first)

        let service = try devices.otherDevice.addStreamingService(name: "Apple TV+")
        try devices.otherDevice.edit(
            try seriesOnTheOtherDevice(devices),
            title: "Severance",
            seasons: Seasons(episodeCounts: [9]),
            status: .watching,
            streamingService: service
        )
        syncLands()

        #expect(devices.thisPhone.trackedSeries.first !== onScreen)
        #expect(probe.wasTold)
    }

    // MARK: - A movie marked watched on another device

    @Test func aRowShowingTheMovieIsToldWhenItIsWatchedElsewhere() throws {
        let devices = try twoDevicesOnOneStore()
        try devices.thisPhone.addTrackedMovie(title: "Arrival")
        syncLands()
        let onScreen = try #require(devices.thisPhone.trackedMovies.first)
        let probe = ObservationProbe()
        withObservationTracking {
            _ = devices.thisPhone.trackedMovies.first?.isWatched
        } onChange: {
            probe.tell()
        }

        let elsewhere = try #require(devices.otherDevice.trackedMovies.first)
        devices.otherDevice.setWatched(true, on: elsewhere)
        syncLands()

        #expect(devices.thisPhone.trackedMovies.first !== onScreen)
        #expect(devices.thisPhone.trackedMovies.first?.isWatched == true)
        #expect(probe.wasTold)
    }

    // MARK: - What a view held from before the sync

    @Test func theEntryCountOfAServiceHeldFromBeforeTheSyncCountsTheEntriesNamingIt() throws {
        let devices = try twoDevicesOnOneStore()
        let heldByTheTab = try devices.thisPhone.addStreamingService(name: "Apple TV+")
        try devices.thisPhone.addTrackedSeries(
            title: "Severance",
            seasons: Seasons(episodeCounts: [9]),
            status: .watching,
            streamingService: heldByTheTab
        )

        syncLands()

        #expect(devices.thisPhone.entryCount(of: heldByTheTab) == 1)
    }

    @Test func anEditOfASeriesHeldFromBeforeTheSyncIsSaved() throws {
        let devices = try twoDevicesOnOneStore()
        let heldBySheet = try devices.thisPhone.addTrackedSeries(
            title: "Severance", seasons: Seasons(episodeCounts: [9]), status: .watching
        )
        syncLands()

        try devices.thisPhone.edit(
            heldBySheet, title: "Severance", seasons: Seasons(episodeCounts: [9, 10]), status: .watching
        )

        #expect(devices.thisPhone.trackedSeries.first?.seasons == Seasons(episodeCounts: [9, 10]))
        syncLands()
        #expect(try seriesOnTheOtherDevice(devices).seasons == Seasons(episodeCounts: [9, 10]))
    }

    @Test func anEditOfAMovieHeldFromBeforeTheSyncIsSaved() throws {
        let devices = try twoDevicesOnOneStore()
        let heldBySheet = try devices.thisPhone.addTrackedMovie(title: "Arival").entry
        syncLands()

        try devices.thisPhone.edit(heldBySheet, title: "Arrival", isWatched: true)

        let movie = try #require(devices.thisPhone.trackedMovies.first)
        #expect(movie.title == "Arrival")
        #expect(movie.isWatched)
    }

    // MARK: - Deleted on another device under an open sheet

    @Test func anEditOfASeriesDeletedElsewhereDoesNotBringItBack() throws {
        let devices = try twoDevicesOnOneStore()
        let heldBySheet = try devices.thisPhone.addTrackedSeries(
            title: "Severance", seasons: Seasons(episodeCounts: [9]), status: .watching
        )
        syncLands()
        devices.otherDevice.delete(.series(try seriesOnTheOtherDevice(devices)))
        syncLands()

        try devices.thisPhone.edit(
            heldBySheet, title: "Severance", seasons: Seasons(episodeCounts: [9]), status: .finished
        )

        #expect(devices.thisPhone.trackedSeries.isEmpty)
        syncLands()
        #expect(devices.otherDevice.trackedSeries.isEmpty)
    }

    @Test func anEditOfASeriesDeletedElsewhereClosesEvenWithABlankTitle() throws {
        let devices = try twoDevicesOnOneStore()
        let heldBySheet = try devices.thisPhone.addTrackedSeries(
            title: "Severance", seasons: Seasons(episodeCounts: [9]), status: .watching
        )
        syncLands()
        devices.otherDevice.delete(.series(try seriesOnTheOtherDevice(devices)))
        syncLands()

        let saved = try devices.thisPhone.edit(
            heldBySheet, title: " ", seasons: Seasons(episodeCounts: [9]), status: .watching
        )

        #expect(saved == nil)
    }

    @Test func anEditOfAMovieDeletedElsewhereClosesEvenWithABlankTitle() throws {
        let devices = try twoDevicesOnOneStore()
        let heldBySheet = try devices.thisPhone.addTrackedMovie(title: "Arrival").entry
        syncLands()
        devices.otherDevice.delete(.movie(try #require(devices.otherDevice.trackedMovies.first)))
        syncLands()

        let saved = try devices.thisPhone.edit(heldBySheet, title: "")

        #expect(saved == nil)
    }

    @Test func anEditOfAMovieDeletedElsewhereDoesNotBringItBack() throws {
        let devices = try twoDevicesOnOneStore()
        let heldBySheet = try devices.thisPhone.addTrackedMovie(title: "Arrival").entry
        syncLands()
        devices.otherDevice.delete(.movie(try #require(devices.otherDevice.trackedMovies.first)))
        syncLands()

        try devices.thisPhone.edit(heldBySheet, title: "Arrival", isWatched: true)

        #expect(devices.thisPhone.trackedMovies.isEmpty)
    }

    @Test func deletingAnEntryAlreadyDeletedElsewhereDoesNothing() throws {
        let devices = try twoDevicesOnOneStore()
        let heldByDialog = try devices.thisPhone.addTrackedMovie(title: "Arrival").entry
        try devices.thisPhone.addTrackedMovie(title: "Dune")
        syncLands()
        let arrival = try #require(devices.otherDevice.trackedMovies.first { $0.title == "Arrival" })
        devices.otherDevice.delete(.movie(arrival))
        syncLands()

        devices.thisPhone.delete(.movie(heldByDialog))

        #expect(devices.thisPhone.trackedMovies.map(\.title) == ["Dune"])
    }

    @Test func renamingAServiceDeletedElsewhereDoesNothing() throws {
        let devices = try twoDevicesOnOneStore()
        let heldBySheet = try devices.thisPhone.addStreamingService(name: "Netflix")
        syncLands()
        devices.otherDevice.deleteStreamingService(
            try #require(devices.otherDevice.streamingServices.first)
        )
        syncLands()

        try devices.thisPhone.renameStreamingService(heldBySheet, to: "Netflix Norge")
        devices.thisPhone.setLogo(Data([1, 2, 3]), on: heldBySheet)

        #expect(devices.thisPhone.streamingServices.isEmpty)
    }

    // MARK: - The picked Streaming Service deleted on another device

    /// A service picked in a sheet on this phone, then deleted on the other device before Save.
    private func servicePickedThenDeletedElsewhere(_ devices: Devices) throws -> StreamingService {
        let picked = try devices.thisPhone.addStreamingService(name: "Netflix")
        syncLands()
        devices.otherDevice.deleteStreamingService(
            try #require(devices.otherDevice.streamingServices.first)
        )
        syncLands()
        return picked
    }

    private let netflixWasDeleted = ServiceDeletedElsewhere(
        serviceName: "Netflix",
        entryTitle: "Severance"
    )

    @Test func aSeriesAddedOnAServiceDeletedElsewhereIsSavedWithoutOneAndSaysSo() throws {
        let devices = try twoDevicesOnOneStore()
        let picked = try servicePickedThenDeletedElsewhere(devices)

        let saved = try devices.thisPhone.addTrackedSeries(
            TrackedSeriesDraft(
                title: " Severance ",
                seasons: Seasons(episodeCounts: [9]),
                status: .watching,
                streamingService: picked
            )
        )

        #expect(saved.serviceDeletedElsewhere == netflixWasDeleted)
        let stored = try #require(devices.thisPhone.trackedSeries.first)
        #expect(stored.streamingService == nil)
    }

    @Test func aSeriesEditedOntoAServiceDeletedElsewhereIsSavedWithoutOneAndSaysSo() throws {
        let devices = try twoDevicesOnOneStore()
        let heldBySheet = try devices.thisPhone.addTrackedSeries(
            title: "Severance", seasons: Seasons(episodeCounts: [9]), status: .watching
        )
        let picked = try servicePickedThenDeletedElsewhere(devices)

        let saved = try devices.thisPhone.edit(
            heldBySheet,
            title: "Severance",
            seasons: Seasons(episodeCounts: [9]),
            status: .finished,
            streamingService: picked
        )

        #expect(saved?.serviceDeletedElsewhere == netflixWasDeleted)
        let stored = try #require(devices.thisPhone.trackedSeries.first)
        #expect(stored.status == .finished)
        #expect(stored.streamingService == nil)
    }

    @Test func aMovieAddedOnAServiceDeletedElsewhereIsSavedWithoutOneAndSaysSo() throws {
        let devices = try twoDevicesOnOneStore()
        let picked = try servicePickedThenDeletedElsewhere(devices)

        let saved = try devices.thisPhone.addTrackedMovie(title: "Arrival", streamingService: picked)

        #expect(saved.serviceDeletedElsewhere?.message
            == "Netflix was deleted on another device, so Arrival was saved without a Streaming Service.")
        #expect(devices.thisPhone.trackedMovies.first?.streamingService == nil)
    }

    @Test func aMovieEditedOntoAServiceDeletedElsewhereIsSavedWithoutOneAndSaysSo() throws {
        let devices = try twoDevicesOnOneStore()
        let heldBySheet = try devices.thisPhone.addTrackedMovie(title: "Arrival").entry
        let picked = try servicePickedThenDeletedElsewhere(devices)

        let saved = try devices.thisPhone.edit(heldBySheet, title: "Arrival", streamingService: picked)

        #expect(saved?.serviceDeletedElsewhere?.serviceName == "Netflix")
        #expect(devices.thisPhone.trackedMovies.first?.streamingService == nil)
    }

    @Test func anEntrySavedOnAServiceStillThereSaysNothing() throws {
        let devices = try twoDevicesOnOneStore()
        let picked = try devices.thisPhone.addStreamingService(name: "Netflix")
        syncLands()

        let saved = try devices.thisPhone.addTrackedMovie(title: "Arrival", streamingService: picked)

        #expect(saved.serviceDeletedElsewhere == nil)
        #expect(saved.entry.streamingService?.name == "Netflix")
    }

    @Test func anEditOfAnEntryDeletedElsewhereSavesNothingAndSaysSo() throws {
        let devices = try twoDevicesOnOneStore()
        let heldBySheet = try devices.thisPhone.addTrackedMovie(title: "Arrival").entry
        syncLands()
        devices.otherDevice.delete(.movie(try #require(devices.otherDevice.trackedMovies.first)))
        syncLands()

        let saved = try devices.thisPhone.edit(heldBySheet, title: "Arrival")

        #expect(saved == nil)
    }

    // MARK: - The Watching tab held still

    /// A series watched on another device moves up the Last Watched order on its next re-take,
    /// not under the user's thumb: the snapshot is persistent IDs, so it holds across the
    /// fresh objects a sync hands out (ADR-0014).
    @Test func theWatchingOrderStaysHeldStillWhenASyncLands() throws {
        let devices = try twoDevicesOnOneStore()
        try devices.thisPhone.addTrackedSeries(title: "Severance", seasons: [9], status: .watching)
        let andor = try devices.thisPhone.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        devices.thisPhone.markNextEpisodeWatched(andor)
        let listing = WatchingListing(library: devices.thisPhone, orderStore: TestOrderStore())
        #expect(listing.series.map(\.title) == ["Andor", "Severance"])
        syncLands()

        devices.otherDevice.markNextEpisodeWatched(try seriesOnTheOtherDevice(devices))
        syncLands()

        #expect(listing.series.map(\.title) == ["Andor", "Severance"])
        #expect(listing.series.first !== andor)
        #expect(listing.series.last?.position == Position(season: 1, episode: 1))
        listing.retake()
        #expect(listing.series.map(\.title) == ["Severance", "Andor"])
    }
}
