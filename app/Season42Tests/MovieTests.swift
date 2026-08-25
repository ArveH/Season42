import Foundation
import Testing
@testable import Season42

/// Tests Tracked Movies against the `Library` facade: adding them, the watched/unwatched
/// toggle, and the fact that a movie is a Library entry and never a Watching-tab one.
@MainActor
struct MovieTests {
    // MARK: - Adding a Tracked Movie

    @Test func anAddedMovieAppearsInTheLibrary() throws {
        let library = try Library.inMemory()

        try library.addTrackedMovie(title: "Arrival")

        #expect(library.trackedMovies.map(\.title) == ["Arrival"])
    }

    @Test func everyFieldIsStoredAsEntered() throws {
        let library = try Library.inMemory()

        let movie = try library.addTrackedMovie(
            title: "Arrival",
            summary: "Linguistics, non-linearly.",
            streamingService: try library.service("Netflix")
        )

        #expect(movie.title == "Arrival")
        #expect(movie.summary == "Linguistics, non-linearly.")
        #expect(movie.streamingService?.name == "Netflix")
    }

    @Test func surroundingWhitespaceIsTrimmedFromTheTitle() throws {
        let library = try Library.inMemory()

        let movie = try library.addTrackedMovie(title: "  Dune  ")

        #expect(movie.title == "Dune")
    }

    @Test func aMovieCanBeTrackedWithNoStreamingService() throws {
        let library = try Library.inMemory()

        let movie = try library.addTrackedMovie(title: "Dune")

        #expect(movie.streamingService == nil)
    }

    @Test(arguments: ["", "   "])
    func aMovieWithoutATitleIsRejected(title: String) throws {
        let library = try Library.inMemory()

        #expect(throws: LibraryError.movieTitleIsBlank) {
            try library.addTrackedMovie(title: title)
        }
        #expect(library.trackedMovies.isEmpty)
    }

    // MARK: - Watched and unwatched

    @Test func aNewMovieIsUnwatched() throws {
        let library = try Library.inMemory()

        let movie = try library.addTrackedMovie(title: "Arrival")

        #expect(!movie.isWatched)
        #expect(movie.watchedAt == nil)
    }

    @Test func markingAMovieWatchedStampsTheDate() throws {
        let watchedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let library = try Library.inMemory(now: { watchedAt })
        let movie = try library.addTrackedMovie(title: "Arrival")

        library.setWatched(true, on: movie)

        #expect(movie.isWatched)
        #expect(movie.watchedAt == watchedAt)
    }

    @Test func unmarkingAWatchedMoviePutsItBackOnTheWatchlist() throws {
        let library = try Library.inMemory()
        let movie = try library.addTrackedMovie(title: "Arrival")
        library.setWatched(true, on: movie)

        library.setWatched(false, on: movie)

        #expect(!movie.isWatched)
    }

    /// The stamp says when the user last saw the movie, not whether they have — so
    /// un-marking corrects the watched state and leaves the date it was seen behind.
    @Test func unmarkingAMovieKeepsTheDateItWasWatched() throws {
        let watchedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let library = try Library.inMemory(now: { watchedAt })
        let movie = try library.addTrackedMovie(title: "Arrival")
        library.setWatched(true, on: movie)

        library.setWatched(false, on: movie)

        #expect(movie.watchedAt == watchedAt)
    }

    @Test func markingAMovieWatchedAgainRestampsTheDate() throws {
        var clock = Date(timeIntervalSince1970: 1_700_000_000)
        let library = try Library.inMemory(now: { clock })
        let movie = try library.addTrackedMovie(title: "Arrival")
        library.setWatched(true, on: movie)

        library.setWatched(false, on: movie)
        clock = clock.addingTimeInterval(3600)
        library.setWatched(true, on: movie)

        #expect(movie.watchedAt == clock)
    }

    // MARK: - How the watched state reads

    /// The words the Library row joins. The date's own formatting is `Date`'s business and
    /// varies by locale, so these pin the wording and which parts appear, not the format.

    @Test func aMovieNeverWatchedJustReadsNotWatched() throws {
        let library = try Library.inMemory()

        let movie = try library.addTrackedMovie(title: "Arrival")

        #expect(movie.watchedState == ["Not watched"])
    }

    @Test func aWatchedMovieReadsWhenItWasWatched() throws {
        let watchedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let library = try Library.inMemory(now: { watchedAt })
        let movie = try library.addTrackedMovie(title: "Arrival")

        library.setWatched(true, on: movie)

        #expect(movie.watchedState == ["Watched \(watchedAt.abbreviatedDate)"])
    }

    @Test func anUnmarkedMovieReadsNotWatchedAndWhenItWasLastSeen() throws {
        let watchedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let library = try Library.inMemory(now: { watchedAt })
        let movie = try library.addTrackedMovie(title: "Arrival")
        library.setWatched(true, on: movie)

        library.setWatched(false, on: movie)

        #expect(movie.watchedState == ["Not watched", "last seen \(watchedAt.abbreviatedDate)"])
    }

    // MARK: - Where movies show up

    @Test func moviesAndSeriesShareOneLibraryListing() throws {
        var clock = Date(timeIntervalSince1970: 1_700_000_000)
        let library = try Library.inMemory(now: { clock })

        try library.addTrackedSeries(title: "Severance", seasons: [9, 10], status: .watching)
        clock = clock.addingTimeInterval(60)
        try library.addTrackedMovie(title: "Arrival")
        clock = clock.addingTimeInterval(60)
        try library.addTrackedSeries(title: "Andor", seasons: [12], status: .planned)

        #expect(library.entries.map(\.title) == ["Andor", "Arrival", "Severance"])
    }

    @Test func aMovieNeverAppearsOnTheWatchingTab() throws {
        let library = try Library.inMemory()

        try library.addTrackedMovie(title: "Arrival")

        #expect(library.watching.isEmpty)
        #expect(library.waiting.isEmpty)
    }

    // MARK: - Persistence

    @Test func aTrackedMovieAndItsWatchedStampSurviveAnAppRelaunch() throws {
        let storeURL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let watchedAt = Date(timeIntervalSince1970: 1_700_000_000)

        let library = Library(container: try Library.container(at: storeURL), now: { watchedAt })
        let movie = try library.addTrackedMovie(
            title: "Arrival",
            streamingService: try library.service("Netflix")
        )
        library.setWatched(true, on: movie)

        let relaunched = Library(container: try Library.container(at: storeURL))

        #expect(relaunched.trackedMovies.map(\.title) == ["Arrival"])
        #expect(relaunched.trackedMovies.first?.streamingService?.name == "Netflix")
        #expect(relaunched.trackedMovies.first?.isWatched == true)
        #expect(relaunched.trackedMovies.first?.watchedAt == watchedAt)
    }
}

private extension Date {
    /// The same rendering `watchedState` asks `Date` for, so the tests assert the wording
    /// around the date rather than the locale's way of writing it.
    var abbreviatedDate: String { formatted(date: .abbreviated, time: .omitted) }
}
