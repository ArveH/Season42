import Foundation
import SwiftData
import Testing
@testable import Season42

/// Tests the `Library` model facade against an in-memory SwiftData container.
/// Persistence is the seam; nothing about how the facade stores things is asserted here.
/// The one type tested below the facade is `Seasons` — see `SeasonsTests`.
@MainActor
struct LibraryTests {
    // MARK: - Creating a Tracked Series

    @Test func aNewLibraryIsEmpty() throws {
        let library = try Library.inMemory()

        #expect(library.trackedSeries.isEmpty)
    }

    @Test func anAddedSeriesAppearsInTheLibrary() throws {
        let library = try Library.inMemory()

        try library.addTrackedSeries(title: "Severance", seasons: [9, 10], status: .watching)

        #expect(library.trackedSeries.map(\.title) == ["Severance"])
    }

    @Test func everyFieldIsStoredAsEntered() throws {
        let library = try Library.inMemory()
        let airDate = Date(timeIntervalSince1970: 1_700_000_000)

        let series = try library.addTrackedSeries(
            title: "Severance",
            summary: "Work-life balance, surgically enforced.",
            seasons: [9, 10],
            status: .waiting,
            position: Position(season: 2, episode: 3),
            streamingService: try library.service("Apple TV+"),
            nextEpisodeDate: airDate,
            releaseSlot: ReleaseSlot(weekday: 3, hour: 21, minute: 0)
        )

        #expect(series.title == "Severance")
        #expect(series.summary == "Work-life balance, surgically enforced.")
        #expect(series.seasons == [9, 10])
        #expect(series.seasons.count == 2)
        #expect(series.status == .waiting)
        #expect(series.position == Position(season: 2, episode: 3))
        #expect(series.streamingService?.name == "Apple TV+")
        #expect(series.nextEpisodeDate == airDate)
        #expect(series.releaseSlot == ReleaseSlot(weekday: 3, hour: 21, minute: 0))
    }

    // MARK: - The Next Episode Line
    //
    // The choice between the Release Slot and the Next Episode Date is made here, once,
    // for every row that lists a Tracked Series (ADR-0016).

    @Test func aSeriesWithOnlyANextEpisodeDateSaysTheDate() throws {
        let library = try Library.inMemory()
        let airDate = Date(timeIntervalSince1970: 1_700_000_000)

        let series = try library.addTrackedSeries(
            title: "Severance",
            seasons: [9],
            status: .waiting,
            nextEpisodeDate: airDate
        )

        #expect(series.nextEpisodeLine == .nextEpisodeDate(airDate))
    }

    @Test func aSeriesWithOnlyAReleaseSlotSaysTheSlot() throws {
        let library = try Library.inMemory()
        let slot = ReleaseSlot(weekday: 3, hour: 21, minute: 0)

        let series = try library.addTrackedSeries(
            title: "Severance",
            seasons: [9],
            status: .waiting,
            releaseSlot: slot
        )

        #expect(series.nextEpisodeLine == .releaseSlot(slot))
    }

    @Test func aSeriesWithBothSaysTheReleaseSlotAndKeepsTheDate() throws {
        let library = try Library.inMemory()
        let airDate = Date(timeIntervalSince1970: 1_700_000_000)
        let slot = ReleaseSlot(weekday: 3, hour: 21, minute: 0)

        let series = try library.addTrackedSeries(
            title: "Severance",
            seasons: [9],
            status: .waiting,
            nextEpisodeDate: airDate,
            releaseSlot: slot
        )

        #expect(series.nextEpisodeLine == .releaseSlot(slot))
        #expect(series.nextEpisodeDate == airDate)
    }

    @Test func aSeriesWithNeitherSaysNothing() throws {
        let library = try Library.inMemory()

        let series = try library.addTrackedSeries(title: "Severance", seasons: [9], status: .waiting)

        #expect(series.nextEpisodeLine == nil)
    }

    @Test func aSeriesWithNoPositionHasWatchedNothing() throws {
        let library = try Library.inMemory()

        let series = try library.addTrackedSeries(title: "Andor", seasons: [12], status: .planned)

        #expect(series.position == nil)
    }

    @Test func aPositionCanBeSetOnCreationToTrackASeriesAlreadyInProgress() throws {
        let library = try Library.inMemory()

        let series = try library.addTrackedSeries(
            title: "The Bear",
            seasons: [8, 10, 10],
            status: .watching,
            position: Position(season: 3, episode: 10)
        )

        #expect(series.position == Position(season: 3, episode: 10))
    }

    @Test(arguments: WatchStatus.allCases)
    func anyOfTheFiveStatusesCanBeSet(status: WatchStatus) throws {
        let library = try Library.inMemory()

        let series = try library.addTrackedSeries(title: "Fringe", seasons: [20], status: status)

        #expect(series.status == status)
    }

    @Test func theStatusesAreExactlyPlannedWatchingWaitingFinishedDropped() {
        #expect(WatchStatus.allCases == [.planned, .watching, .waiting, .finished, .dropped])
    }

    @Test func severalSeriesAreListedNewestFirst() throws {
        let library = try Library.inMemory()

        try library.addTrackedSeries(title: "First", seasons: [1], status: .planned)
        try library.addTrackedSeries(title: "Second", seasons: [1], status: .planned)

        #expect(library.trackedSeries.map(\.title) == ["Second", "First"])
    }

    // MARK: - Optional fields

    @Test func aSeriesCanBeTrackedWithNoStreamingService() throws {
        let library = try Library.inMemory()

        let series = try library.addTrackedSeries(title: "Dark", seasons: [10], status: .finished)

        #expect(series.streamingService == nil)
    }

    @Test func surroundingWhitespaceIsTrimmedFromTheTitle() throws {
        let library = try Library.inMemory()

        let series = try library.addTrackedSeries(title: "  Silo  ", seasons: [10], status: .watching)

        #expect(series.title == "Silo")
    }

    // MARK: - Validation

    @Test(arguments: ["", "   "])
    func aSeriesWithoutATitleIsRejected(title: String) throws {
        let library = try Library.inMemory()

        #expect(throws: LibraryError.seriesTitleIsBlank) {
            try library.addTrackedSeries(title: title, seasons: [10], status: .planned)
        }
    }

    @Test func aSeriesWithNoSeasonsIsRejected() throws {
        let library = try Library.inMemory()

        #expect(throws: LibraryError.seriesHasNoSeasons) {
            try library.addTrackedSeries(title: "Ghosts", seasons: Seasons(episodeCounts: []), status: .planned)
        }
    }

    @Test(arguments: [0, -1])
    func aSeasonWithoutEpisodesIsRejected(episodeCount: Int) throws {
        let library = try Library.inMemory()

        #expect(throws: LibraryError.seasonHasNoEpisodes(season: 2)) {
            try library.addTrackedSeries(
                title: "Ghosts",
                seasons: Seasons(episodeCounts: [6, episodeCount]),
                status: .planned
            )
        }
    }

    @Test func aPositionBeyondTheLastSeasonIsRejected() throws {
        let library = try Library.inMemory()
        let position = Position(season: 3, episode: 1)

        #expect(throws: LibraryError.positionOutOfRange(position)) {
            try library.addTrackedSeries(
                title: "Severance",
                seasons: [9, 10],
                status: .watching,
                position: position
            )
        }
    }

    @Test func aPositionBeyondThatSeasonsEpisodeCountIsRejected() throws {
        let library = try Library.inMemory()
        let position = Position(season: 1, episode: 10)

        #expect(throws: LibraryError.positionOutOfRange(position)) {
            try library.addTrackedSeries(
                title: "Severance",
                seasons: [9, 10],
                status: .watching,
                position: position
            )
        }
    }

    @Test(arguments: [Position(season: 0, episode: 1), Position(season: 1, episode: 0)])
    func aPositionBelowSeasonOneEpisodeOneIsRejected(position: Position) throws {
        let library = try Library.inMemory()

        #expect(throws: LibraryError.positionOutOfRange(position)) {
            try library.addTrackedSeries(
                title: "Severance",
                seasons: [9, 10],
                status: .watching,
                position: position
            )
        }
    }

    @Test func thePositionAtTheVeryLastEpisodeIsAccepted() throws {
        let library = try Library.inMemory()

        let series = try library.addTrackedSeries(
            title: "Severance",
            seasons: [9, 10],
            status: .watching,
            position: Position(season: 2, episode: 10)
        )

        #expect(series.position == Position(season: 2, episode: 10))
    }

    @Test func aRejectedSeriesIsNotAddedToTheLibrary() throws {
        let library = try Library.inMemory()

        #expect(throws: (any Error).self) {
            try library.addTrackedSeries(title: "", seasons: [10], status: .planned)
        }

        #expect(library.trackedSeries.isEmpty)
    }

    // MARK: - Persistence

    /// The one test that touches a real file: an in-memory store cannot tell a saved
    /// series apart from one merely still registered in the context it was inserted into.
    @Test func aTrackedSeriesSurvivesAnAppRelaunch() throws {
        let storeURL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let library = Library(container: try Library.container(at: storeURL))
        try library.addTrackedSeries(
            title: "Severance",
            seasons: [9, 10],
            status: .watching,
            position: Position(season: 1, episode: 4)
        )

        let relaunched = Library(container: try Library.container(at: storeURL))

        #expect(relaunched.trackedSeries.map(\.title) == ["Severance"])
        #expect(relaunched.trackedSeries.first?.seasons == [9, 10])
        #expect(relaunched.trackedSeries.first?.status == .watching)
        #expect(relaunched.trackedSeries.first?.position == Position(season: 1, episode: 4))
    }

    /// A store written before the schema was versioned — opened, as the app used to, with a
    /// plain `Schema` of the same models — opens through the migration plan with every
    /// value and every Streaming Service link it held (ADR-0023).
    @Test func aStoreWrittenBeforeTheSchemaWasVersionedOpensWithEverythingInIt() throws {
        let directory = try temporaryStoreDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "default.store")
        let addedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let nextEpisodeDate = Date(timeIntervalSince1970: 1_800_500_000)

        do {
            let unversioned = Schema([TrackedSeries.self, TrackedMovie.self, StreamingService.self])
            let container = try ModelContainer(
                for: unversioned,
                configurations: ModelConfiguration(schema: unversioned, url: storeURL)
            )
            let old = Library(container: container, now: { addedAt })
            let tv = try old.addStreamingService(name: "Apple TV+", logo: Data("logo".utf8))
            let bare = try old.addStreamingService(name: "Netflix")
            let series = try old.addTrackedSeries(TrackedSeriesDraft(
                title: "Severance",
                summary: "Work and life, severed.",
                poster: Data("poster".utf8),
                seasons: [9, 10],
                status: .watching,
                position: Position(season: 1, episode: 4),
                streamingService: tv,
                nextEpisodeDate: nextEpisodeDate,
                releaseSlot: ReleaseSlot(weekday: 6, hour: 3, minute: 0)
            ))
            old.markNextEpisodeWatched(series)
            try old.addTrackedSeries(TrackedSeriesDraft(title: "Dark", seasons: [10], status: .planned))
            let movie = try old.addTrackedMovie(
                title: "Arrival",
                summary: "Heptapods.",
                poster: Data("movie poster".utf8),
                streamingService: tv
            )
            old.setWatched(true, on: movie)
            try old.addTrackedMovie(title: "Heat", streamingService: bare)
        }

        let library = try Library.onDisk(at: storeURL)

        #expect(library.keptAsideStore == nil)
        #expect(Set(library.trackedSeries.map(\.title)) == ["Severance", "Dark"])
        let severance = try #require(library.trackedSeries.first { $0.title == "Severance" })
        #expect(severance.summary == "Work and life, severed.")
        #expect(severance.poster == Data("poster".utf8))
        #expect(severance.seasons == [9, 10])
        #expect(severance.status == .watching)
        #expect(severance.position == Position(season: 1, episode: 5))
        #expect(severance.nextEpisodeDate == nextEpisodeDate)
        #expect(severance.releaseSlot == ReleaseSlot(weekday: 6, hour: 3, minute: 0))
        #expect(severance.addedAt == addedAt)
        #expect(severance.lastWatchedAt == addedAt)
        #expect(severance.streamingService?.name == "Apple TV+")
        let dark = try #require(library.trackedSeries.first { $0.title == "Dark" })
        #expect(dark.status == .planned)
        #expect(dark.position == nil)
        #expect(dark.streamingService == nil)

        #expect(Set(library.trackedMovies.map(\.title)) == ["Arrival", "Heat"])
        let arrival = try #require(library.trackedMovies.first { $0.title == "Arrival" })
        #expect(arrival.summary == "Heptapods.")
        #expect(arrival.poster == Data("movie poster".utf8))
        #expect(arrival.isWatched)
        #expect(arrival.watchedAt == addedAt)
        #expect(arrival.streamingService?.name == "Apple TV+")
        let heat = try #require(library.trackedMovies.first { $0.title == "Heat" })
        #expect(heat.streamingService?.name == "Netflix")

        #expect(library.streamingServices.map(\.name) == ["Apple TV+", "Netflix"])
        let tv = try #require(library.streamingServices.first)
        #expect(tv.logo == Data("logo".utf8))
        #expect(Set(tv.series.map(\.title)) == ["Severance"])
        #expect(Set(tv.movies.map(\.title)) == ["Arrival"])
        let netflix = try #require(library.streamingServices.last)
        #expect(netflix.logo == nil)
        #expect(netflix.series.isEmpty)
        #expect(netflix.movies.map(\.title) == ["Heat"])
    }

    /// A store the app's schema cannot open — one written by a shape of the models that
    /// no longer exists — is moved aside and kept, and a fresh store opens in its place,
    /// rather than taking the launch with it (ADR-0023). A file that is not a store at all
    /// stands in for it: what matters is that opening failed, not why.
    @Test func aStoreThatCannotBeOpenedIsKeptAsideAndAnEmptyOneOpens() throws {
        let directory = try temporaryStoreDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "default.store")
        try Data("not a store".utf8).write(to: storeURL)

        let library = try Library.onDisk(at: storeURL)

        #expect(library.entries.isEmpty)
        let keptAside = try #require(library.keptAsideStore)
        #expect(try Data(contentsOf: keptAside) == Data("not a store".utf8))

        // And what replaced it is a working store, not one that merely opened once.
        try library.addTrackedSeries(title: "Severance", seasons: [9], status: .watching)
        let relaunched = try Library.onDisk(at: storeURL)

        #expect(relaunched.trackedSeries.map(\.title) == ["Severance"])
        #expect(relaunched.keptAsideStore == nil)
    }

    /// Everything SQLite and SwiftData keep beside a store goes with it, under the names it
    /// had: a write-ahead log left behind would be replayed into the fresh store, and one
    /// moved under another name is no use to a recovery by hand.
    @Test func aStoreIsKeptAsideWithEverythingKeptBesideIt() throws {
        let directory = try temporaryStoreDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("not a store".utf8).write(to: directory.appending(path: "default.store"))
        try Data("log".utf8).write(to: directory.appending(path: "default.store-wal"))
        try Data("memory".utf8).write(to: directory.appending(path: "default.store-shm"))
        let support = directory.appending(path: ".default_SUPPORT")
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try Data("poster".utf8).write(to: support.appending(path: "poster"))

        let library = try Library.onDisk(at: directory.appending(path: "default.store"))

        let keptAside = try #require(library.keptAsideStore).deletingLastPathComponent()
        #expect(try Data(contentsOf: keptAside.appending(path: "default.store-wal")) == Data("log".utf8))
        // SQLite rewrites the shared-memory index while it tries the open — it is scratch,
        // rebuilt from the log — so only that it went along is the store's to keep.
        #expect(FileManager.default.fileExists(
            atPath: keptAside.appending(path: "default.store-shm").path(percentEncoded: false)
        ))
        #expect(
            try Data(contentsOf: keptAside.appending(path: ".default_SUPPORT/poster"))
                == Data("poster".utf8)
        )
    }

    /// The store the app itself runs against lives in `Application Support`, so keeping a
    /// store aside has to survive a space in the path — a directory read that percent
    /// encodes one finds nothing to move, and the fresh open fails on the store that is
    /// still sitting there.
    @Test func aStoreInADirectoryWithASpaceInItsNameIsKeptAsideToo() throws {
        let directory = try temporaryStoreDirectory(named: "Application Support \(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "default.store")
        try Data("not a store".utf8).write(to: storeURL)

        let library = try Library.onDisk(at: storeURL)
        try library.addTrackedSeries(title: "Severance", seasons: [9], status: .watching)

        let relaunched = try Library.onDisk(at: storeURL)

        #expect(relaunched.trackedSeries.map(\.title) == ["Severance"])
        let keptAside = try #require(library.keptAsideStore)
        #expect(try Data(contentsOf: keptAside) == Data("not a store".utf8))
    }

    /// A second store that won't open is kept beside the first, not over it — both
    /// within the same second, which is as close together as two launches can be.
    @Test func aSecondStoreKeptAsideDoesNotOverwriteTheFirst() throws {
        let directory = try temporaryStoreDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "default.store")
        try Data("first".utf8).write(to: storeURL)
        let first = try Library.onDisk(at: storeURL)
        try FileManager.default.removeItem(at: storeURL)
        for suffix in ["-wal", "-shm"] {
            try? FileManager.default.removeItem(at: directory.appending(path: "default.store" + suffix))
        }
        try Data("second".utf8).write(to: storeURL)

        let second = try Library.onDisk(at: storeURL)

        let firstKept = try #require(first.keptAsideStore)
        let secondKept = try #require(second.keptAsideStore)
        #expect(firstKept != secondKept)
        #expect(try Data(contentsOf: firstKept) == Data("first".utf8))
        #expect(try Data(contentsOf: secondKept) == Data("second".utf8))
    }

    /// Where the store can be neither moved aside nor replaced, the open fails with both
    /// errors — the first is the one that says why the store had to go — and the store is
    /// still where it was: nothing deletes it to make room.
    @Test func aStoreThatCanBeNeitherKeptAsideNorReplacedFailsWithBothErrorsAndStays() throws {
        let directory = try temporaryStoreDirectory()
        let storeURL = directory.appending(path: "default.store")
        try Data("not a store".utf8).write(to: storeURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path(percentEncoded: false))
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path(percentEncoded: false))
            try? FileManager.default.removeItem(at: directory)
        }

        #expect(throws: LibraryStoreError.self) { try Library.onDisk(at: storeURL) }
        #expect(try Data(contentsOf: storeURL) == Data("not a store".utf8))
    }
}

/// `Seasons` is the one piece of arithmetic the facade delegates to, and the add form
/// leans on it to keep a Position legal while the user edits season lengths.
struct SeasonsTests {
    @Test func aSeasonIsAddressedByItsOneBasedNumber() {
        let seasons: Seasons = [9, 10]

        #expect(seasons.count == 2)
        #expect(seasons.episodeCount(inSeason: 1) == 9)
        #expect(seasons.episodeCount(inSeason: 2) == 10)
        #expect(seasons.episodeCount(inSeason: 3) == nil)
        #expect(seasons.episodeCount(inSeason: 0) == nil)
    }

    @Test func everySeasonNumberIsHandedOutInOrderAndTheEpisodesAdded() {
        let seasons: Seasons = [9, 10]

        #expect(seasons.seasonNumbers == [1, 2])
        #expect(seasons.totalEpisodes == 19)
    }

    @Test func aSeriesWithNoSeasonsHasNoSeasonNumbersAndNoEpisodes() {
        let seasons = Seasons(episodeCounts: [])

        #expect(seasons.seasonNumbers.isEmpty)
        #expect(seasons.totalEpisodes == 0)
    }

    @Test func onlyPositionsTheSeriesActuallyHasAreContained() {
        let seasons: Seasons = [9, 10]

        #expect(seasons.contains(Position(season: 2, episode: 10)))
        #expect(!seasons.contains(Position(season: 1, episode: 10)))
        #expect(!seasons.contains(Position(season: 3, episode: 1)))
        #expect(!seasons.contains(Position(season: 1, episode: 0)))
    }

    @Test func clampingPullsAPositionBackInsideTheSeries() {
        let seasons: Seasons = [9, 10]

        #expect(seasons.clamping(Position(season: 3, episode: 4)) == Position(season: 2, episode: 4))
        #expect(seasons.clamping(Position(season: 1, episode: 40)) == Position(season: 1, episode: 9))
        #expect(seasons.clamping(Position(season: 2, episode: 3)) == Position(season: 2, episode: 3))
    }

    @Test func aNewSeasonStartsOutAsLongAsTheOneBeforeIt() {
        var seasons: Seasons = [9]

        seasons.setCount(3)

        #expect(seasons == [9, 9, 9])
    }

    @Test func shrinkingKeepsTheEpisodeCountsAlreadyEntered() {
        var seasons: Seasons = [9, 10, 6]

        seasons.setCount(2)

        #expect(seasons == [9, 10])
    }

    @Test func theFirstSeasonLeftWithoutEpisodesIsReported() {
        #expect((Seasons(episodeCounts: [9, 0, 0])).firstSeasonWithoutEpisodes == 2)
        #expect((Seasons(episodeCounts: [9, 10])).firstSeasonWithoutEpisodes == nil)
    }

    // MARK: - Stepping through episodes

    @Test func theEpisodeAfterOneMidSeasonIsTheNextInThatSeason() {
        let seasons: Seasons = [9, 10]

        #expect(seasons.episode(after: Position(season: 1, episode: 4)) == Position(season: 1, episode: 5))
    }

    @Test func theEpisodeAfterASeasonsLastIsTheNextSeasonsFirst() {
        let seasons: Seasons = [9, 10]

        #expect(seasons.episode(after: Position(season: 1, episode: 9)) == Position(season: 2, episode: 1))
    }

    @Test func thereIsNoEpisodeAfterTheLastEpisodeOfTheLastSeason() {
        let seasons: Seasons = [9, 10]

        #expect(seasons.episode(after: Position(season: 2, episode: 10)) == nil)
    }

    @Test func theEpisodeBeforeOneMidSeasonIsThePreviousInThatSeason() {
        let seasons: Seasons = [9, 10]

        #expect(seasons.episode(before: Position(season: 2, episode: 5)) == Position(season: 2, episode: 4))
    }

    @Test func theEpisodeBeforeASeasonsFirstIsThePreviousSeasonsLast() {
        let seasons: Seasons = [9, 10]

        #expect(seasons.episode(before: Position(season: 2, episode: 1)) == Position(season: 1, episode: 9))
    }

    @Test func thereIsNoEpisodeBeforeTheVeryFirstOne() {
        let seasons: Seasons = [9, 10]

        #expect(seasons.episode(before: Position(season: 1, episode: 1)) == nil)
    }

    @Test func steppingFromAPositionTheSeriesDoesNotHaveGoesNowhere() {
        let seasons: Seasons = [9, 10]

        #expect(seasons.episode(after: Position(season: 3, episode: 1)) == nil)
        #expect(seasons.episode(before: Position(season: 3, episode: 1)) == nil)
    }
}
