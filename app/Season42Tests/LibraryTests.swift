import Foundation
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
            streamingService: "Apple TV+",
            nextEpisodeDate: airDate
        )

        #expect(series.title == "Severance")
        #expect(series.summary == "Work-life balance, surgically enforced.")
        #expect(series.seasons == [9, 10])
        #expect(series.seasons.count == 2)
        #expect(series.status == .waiting)
        #expect(series.position == Position(season: 2, episode: 3))
        #expect(series.streamingService == "Apple TV+")
        #expect(series.nextEpisodeDate == airDate)
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

    @Test func aBlankStreamingServiceIsStoredAsNoService() throws {
        let library = try Library.inMemory()

        let series = try library.addTrackedSeries(
            title: "Dark",
            seasons: [10],
            status: .finished,
            streamingService: "   "
        )

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
