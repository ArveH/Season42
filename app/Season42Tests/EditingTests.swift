import Foundation
import Testing
@testable import Season42

/// Tests editing and deleting what is already in the Library, against the `Library`
/// facade. An edit answers to exactly the same rules a new entry does; deletion is
/// permanent.
@MainActor
struct EditingTests {
    // MARK: - Editing a Tracked Series

    @Test func everyFieldOfASeriesCanBeChanged() throws {
        let library = try Library.inMemory()
        let airDate = Date(timeIntervalSince1970: 1_700_000_000)
        let series = try library.addTrackedSeries(title: "Severence", seasons: [9], status: .planned)

        try library.updateTrackedSeries(
            series,
            title: "Severance",
            summary: "Work-life balance, surgically enforced.",
            seasons: [9, 10],
            status: .waiting,
            position: Position(season: 2, episode: 3),
            streamingService: try library.service("Apple TV+"),
            nextEpisodeDate: airDate
        )

        #expect(series.title == "Severance")
        #expect(series.summary == "Work-life balance, surgically enforced.")
        #expect(series.seasons == [9, 10])
        #expect(series.status == .waiting)
        #expect(series.position == Position(season: 2, episode: 3))
        #expect(series.streamingService?.name == "Apple TV+")
        #expect(series.nextEpisodeDate == airDate)
    }

    /// Adding a season by hand is the only way a returning series gets its new episodes:
    /// the Library is where a series is entered and the only place it is stored (ADR-0005).
    @Test func aSeasonCanBeAddedToASeriesThatDidNotHaveIt() throws {
        let library = try Library.inMemory()
        let series = try library.addTrackedSeries(
            title: "Severance",
            seasons: [9],
            status: .waiting,
            position: Position(season: 1, episode: 9)
        )

        try library.edit(
            series,
            title: series.title,
            seasons: [9, 10],
            status: .watching,
            position: series.position
        )

        #expect(series.seasons == [9, 10])
        #expect(series.position == Position(season: 1, episode: 9))
        #expect(series.nextEpisode == Position(season: 2, episode: 1))
    }

    @Test func anEditCanClearTheOptionalFields() throws {
        let library = try Library.inMemory()
        let series = try library.addTrackedSeries(
            title: "Severance",
            summary: "A note.",
            seasons: [9],
            status: .watching,
            position: Position(season: 1, episode: 2),
            streamingService: try library.service("Apple TV+"),
            nextEpisodeDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        try library.edit(series, title: "Severance", seasons: [9], status: .planned)

        #expect(series.summary.isEmpty)
        #expect(series.position == nil)
        #expect(series.streamingService == nil)
        #expect(series.nextEpisodeDate == nil)
    }

    @Test func anEditLeavesWhenTheSeriesWasAddedAndLastWatchedAlone() throws {
        var clock = Date(timeIntervalSince1970: 1_700_000_000)
        let library = try Library.inMemory(now: { clock })
        let series = try library.addTrackedSeries(title: "Severance", seasons: [9], status: .watching)
        library.markNextEpisodeWatched(series)
        let addedAt = series.addedAt
        let lastWatchedAt = series.lastWatchedAt

        clock = clock.addingTimeInterval(3600)
        try library.edit(series, title: "Severance!", seasons: [9], status: .watching)

        #expect(series.addedAt == addedAt)
        #expect(series.lastWatchedAt == lastWatchedAt)
    }

    @Test func anEditedTitleIsTrimmed() throws {
        let library = try Library.inMemory()
        let series = try library.addTrackedSeries(title: "Silo", seasons: [10], status: .watching)

        try library.edit(series, title: "  Silo  ", seasons: [10], status: .watching)

        #expect(series.title == "Silo")
    }

    // MARK: - An edit answers to the same rules a new series does

    @Test(arguments: ["", "   "])
    func anEditThatBlanksTheTitleIsRejected(title: String) throws {
        let library = try Library.inMemory()
        let series = try library.addTrackedSeries(title: "Severance", seasons: [9], status: .watching)

        #expect(throws: LibraryError.seriesTitleIsBlank) {
            try library.edit(series, title: title, seasons: [9], status: .watching)
        }
        #expect(series.title == "Severance")
    }

    @Test func anEditThatRemovesEverySeasonIsRejected() throws {
        let library = try Library.inMemory()
        let series = try library.addTrackedSeries(title: "Severance", seasons: [9], status: .watching)

        #expect(throws: LibraryError.seriesHasNoSeasons) {
            try library.edit(
                series,
                title: "Severance",
                seasons: Seasons(episodeCounts: []),
                status: .watching
            )
        }
        #expect(series.seasons == [9])
    }

    @Test func anEditThatEmptiesASeasonIsRejected() throws {
        let library = try Library.inMemory()
        let series = try library.addTrackedSeries(title: "Severance", seasons: [9, 10], status: .watching)

        #expect(throws: LibraryError.seasonHasNoEpisodes(season: 2)) {
            try library.edit(
                series,
                title: "Severance",
                seasons: Seasons(episodeCounts: [9, 0]),
                status: .watching
            )
        }
    }

    /// Shrinking a series under the Position the user is at would leave them somewhere the
    /// series no longer has, so the edit is refused whole rather than silently moved.
    @Test func anEditThatLeavesThePositionOutsideTheSeriesIsRejected() throws {
        let library = try Library.inMemory()
        let position = Position(season: 2, episode: 3)
        let series = try library.addTrackedSeries(
            title: "Severance",
            seasons: [9, 10],
            status: .watching,
            position: position
        )

        #expect(throws: LibraryError.positionOutOfRange(position)) {
            try library.edit(
                series,
                title: "Severance",
                seasons: [9],
                status: .watching,
                position: position
            )
        }
        #expect(series.seasons == [9, 10])
        #expect(series.position == position)
    }

    // MARK: - Editing a Tracked Movie

    @Test func everyFieldOfAMovieCanBeChanged() throws {
        let library = try Library.inMemory()
        let movie = try library.addTrackedMovie(title: "Arival")

        try library.updateTrackedMovie(
            movie,
            title: "Arrival",
            summary: "Linguistics, non-linearly.",
            streamingService: try library.service("Netflix"),
            isWatched: true
        )

        #expect(movie.title == "Arrival")
        #expect(movie.summary == "Linguistics, non-linearly.")
        #expect(movie.streamingService?.name == "Netflix")
        #expect(movie.isWatched)
    }

    @Test func markingAMovieWatchedThroughAnEditStampsTheDate() throws {
        var clock = Date(timeIntervalSince1970: 1_700_000_000)
        let library = try Library.inMemory(now: { clock })
        let movie = try library.addTrackedMovie(title: "Arrival")

        clock = clock.addingTimeInterval(3600)
        try library.edit(movie, title: "Arrival", isWatched: true)

        #expect(movie.watchedAt == clock)
    }

    /// Editing a movie's title is not watching it again: only a change of watched state
    /// moves the stamp, exactly as tapping the row's toggle does.
    @Test func anEditThatLeavesTheWatchedStateAloneKeepsTheStamp() throws {
        var clock = Date(timeIntervalSince1970: 1_700_000_000)
        let library = try Library.inMemory(now: { clock })
        let movie = try library.addTrackedMovie(title: "Arrival")
        library.setWatched(true, on: movie)
        let watchedAt = movie.watchedAt

        clock = clock.addingTimeInterval(3600)
        try library.edit(movie, title: "Arrival!", isWatched: true)

        #expect(movie.watchedAt == watchedAt)
    }

    @Test func unmarkingAMovieThroughAnEditKeepsTheStamp() throws {
        let watchedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let library = try Library.inMemory(now: { watchedAt })
        let movie = try library.addTrackedMovie(title: "Arrival")
        library.setWatched(true, on: movie)

        try library.edit(movie, title: "Arrival", isWatched: false)

        #expect(!movie.isWatched)
        #expect(movie.watchedAt == watchedAt)
    }

    @Test(arguments: ["", "   "])
    func anEditThatBlanksAMovieTitleIsRejected(title: String) throws {
        let library = try Library.inMemory()
        let movie = try library.addTrackedMovie(title: "Arrival")

        #expect(throws: LibraryError.movieTitleIsBlank) {
            try library.edit(movie, title: title)
        }
        #expect(movie.title == "Arrival")
    }

    @Test func anEditedMovieTitleIsTrimmed() throws {
        let library = try Library.inMemory()
        let movie = try library.addTrackedMovie(
            title: "Dune",
            streamingService: try library.service("Netflix")
        )

        try library.edit(movie, title: "  Dune  ", streamingService: movie.streamingService)

        #expect(movie.title == "Dune")
    }

    // MARK: - Deleting

    @Test func aDeletedSeriesLeavesTheLibraryForGood() throws {
        let library = try Library.inMemory()
        let series = try library.addTrackedSeries(title: "Severance", seasons: [9], status: .watching)
        try library.addTrackedSeries(title: "Andor", seasons: [12], status: .planned)

        library.delete(.series(series))

        #expect(library.trackedSeries.map(\.title) == ["Andor"])
        #expect(library.entries.map(\.title) == ["Andor"])
        #expect(library.watching.isEmpty)
    }

    @Test func aDeletedMovieLeavesTheLibraryForGood() throws {
        let library = try Library.inMemory()
        let movie = try library.addTrackedMovie(title: "Arrival")

        library.delete(.movie(movie))

        #expect(library.trackedMovies.isEmpty)
        #expect(library.entries.isEmpty)
    }

    // MARK: - Persistence

    @Test func anEditAndADeletionSurviveAnAppRelaunch() throws {
        let storeURL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let library = Library(container: try Library.container(at: storeURL))
        let series = try library.addTrackedSeries(title: "Severence", seasons: [9], status: .planned)
        let movie = try library.addTrackedMovie(title: "Arrival")
        try library.edit(
            series,
            title: "Severance",
            seasons: [9, 10],
            status: .watching,
            position: Position(season: 2, episode: 1)
        )
        library.delete(.movie(movie))

        let relaunched = Library(container: try Library.container(at: storeURL))

        #expect(relaunched.trackedSeries.map(\.title) == ["Severance"])
        #expect(relaunched.trackedSeries.first?.seasons == [9, 10])
        #expect(relaunched.trackedSeries.first?.status == .watching)
        #expect(relaunched.trackedSeries.first?.position == Position(season: 2, episode: 1))
        #expect(relaunched.trackedMovies.isEmpty)
    }
}

/// An edit rewrites an entry whole, so the facade spells every field out and clears what
/// a caller leaves out. These let a test name only the fields it is about; leaving one out
/// clears it, exactly as clearing it in the form does.
@MainActor
private extension Library {
    func edit(
        _ series: TrackedSeries,
        title: String,
        summary: String = "",
        seasons: Seasons,
        status: WatchStatus,
        position: Position? = nil,
        streamingService: StreamingService? = nil,
        nextEpisodeDate: Date? = nil
    ) throws {
        try updateTrackedSeries(
            series,
            title: title,
            summary: summary,
            seasons: seasons,
            status: status,
            position: position,
            streamingService: streamingService,
            nextEpisodeDate: nextEpisodeDate
        )
    }

    func edit(
        _ movie: TrackedMovie,
        title: String,
        summary: String = "",
        streamingService: StreamingService? = nil,
        isWatched: Bool = false
    ) throws {
        try updateTrackedMovie(
            movie,
            title: title,
            summary: summary,
            streamingService: streamingService,
            isWatched: isWatched
        )
    }
}
