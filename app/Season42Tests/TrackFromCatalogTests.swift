import Foundation
import Testing
@testable import Season42

/// Tests tracking a Catalog entry: what the copy carries, how the Catalog tab knows an
/// entry is already tracked, and — the point of ADR-0002 — that the copy and the Catalog
/// go their separate ways the moment the copy exists.
@MainActor
struct TrackFromCatalogTests {
    // MARK: - Copying a Catalog Series

    @Test func trackingACatalogSeriesCopiesWhatTheCatalogKnowsAboutIt() throws {
        let (library, catalog) = try theBearAndPastLives()
        let bear = try #require(catalog.series.first)

        let tracked = try library.track(bear, status: .planned)

        #expect(tracked.title == "The Bear")
        #expect(tracked.summary == bear.summary)
        #expect(tracked.seasons.episodeCounts == [8, 10])
        #expect(library.trackedSeries.map(\.title) == ["The Bear"])
    }

    @Test func aTrackedCopyStartsWithTheStatusTheUserPickedAndNothingWatched() throws {
        let (library, catalog) = try theBearAndPastLives()
        let bear = try #require(catalog.series.first)

        let tracked = try library.track(bear, status: .watching)

        #expect(tracked.status == .watching)
        #expect(tracked.position == nil)
        #expect(tracked.lastWatchedAt == nil)
        #expect(tracked.nextEpisode == Position(season: 1, episode: 1))
    }

    @Test func aTrackedCopyCarriesNothingTheUserHasNotSaidYet() throws {
        let (library, catalog) = try theBearAndPastLives()
        let bear = try #require(catalog.series.first)

        let tracked = try library.track(bear, status: .planned)

        // Where they watch it and when it comes back are the user's to enter; the Catalog
        // says nothing about either.
        #expect(tracked.streamingService == nil)
        #expect(tracked.nextEpisodeDate == nil)
    }

    @Test func aTrackedCopyIsStampedAsAddedNow() throws {
        var now = Date(timeIntervalSince1970: 1_000)
        let library = try Library.inMemory(now: { now })
        let catalog = try Catalog.inMemory()
        try catalog.fill(from: .justTheBear)
        let bear = try #require(catalog.series.first)

        now = Date(timeIntervalSince1970: 2_000)
        let tracked = try library.track(bear, status: .planned)

        #expect(tracked.addedAt == Date(timeIntervalSince1970: 2_000))
    }

    // MARK: - Copying a Catalog Movie

    @Test func trackingACatalogMovieCopiesItAsAnUnwatchedTrackedMovie() throws {
        let (library, catalog) = try theBearAndPastLives()
        let pastLives = try #require(catalog.movies.first)

        let tracked = try library.track(pastLives)

        #expect(tracked.title == "Past Lives")
        #expect(tracked.summary == pastLives.summary)
        #expect(!tracked.isWatched)
        #expect(tracked.watchedAt == nil)
        #expect(tracked.streamingService == nil)
        #expect(library.trackedMovies.map(\.title) == ["Past Lives"])
    }

    @Test func aTrackedCopyOfEitherKindIsJustAnotherLibraryEntry() throws {
        let (library, catalog) = try theBearAndPastLives()

        try library.track(try #require(catalog.series.first), status: .planned)
        try library.track(try #require(catalog.movies.first))

        #expect(Set(library.entries.map(\.title)) == ["The Bear", "Past Lives"])
    }

    // MARK: - Knowing what is already tracked

    @Test func aCatalogEntryIsMarkedOnceItIsTracked() throws {
        let (library, catalog) = try theBearAndPastLives()
        let bear = try #require(catalog.series.first)
        let pastLives = try #require(catalog.movies.first)
        #expect(!library.isTracked(bear))
        #expect(!library.isTracked(pastLives))

        try library.track(bear, status: .planned)

        #expect(library.isTracked(bear))
        #expect(!library.isTracked(pastLives))
    }

    /// The mark is about the title, not about where the entry came from: a series the
    /// user typed in by hand is the duplicate the mark exists to prevent.
    @Test func aHandEnteredEntryMarksTheCatalogEntryItDuplicates() throws {
        let (library, catalog) = try theBearAndPastLives()
        let bear = try #require(catalog.series.first)

        try library.addTrackedSeries(title: "  the bear ", seasons: [8], status: .finished)

        #expect(library.isTracked(bear))
    }

    @Test func aTrackedSeriesDoesNotMarkAMovieOfTheSameName() throws {
        let library = try Library.inMemory()
        let catalog = try Catalog.inMemory()
        try catalog.fill(from: .dune)
        let movie = try #require(catalog.movies.first)
        let series = try #require(catalog.series.first)

        try library.addTrackedSeries(title: "Dune", seasons: [6], status: .watching)

        #expect(library.isTracked(series))
        #expect(!library.isTracked(movie))
    }

    @Test func renamingATrackedCopyUnmarksTheCatalogEntry() throws {
        let (library, catalog) = try theBearAndPastLives()
        let bear = try #require(catalog.series.first)
        let tracked = try library.track(bear, status: .planned)

        try library.updateTrackedSeries(
            tracked,
            title: "The Bear (rewatch)",
            summary: tracked.summary,
            seasons: tracked.seasons,
            status: .watching,
            position: nil,
            streamingService: nil,
            nextEpisodeDate: nil
        )

        #expect(!library.isTracked(bear))
    }

    @Test func deletingTheCopyUnmarksTheCatalogEntry() throws {
        let (library, catalog) = try theBearAndPastLives()
        let pastLives = try #require(catalog.movies.first)
        let tracked = try library.track(pastLives)

        library.delete(.movie(tracked))

        #expect(!library.isTracked(pastLives))
    }

    // MARK: - The copy and the Catalog go separate ways (ADR-0002)

    @Test func editingTheCopyLeavesTheCatalogEntryAlone() throws {
        let (library, catalog) = try theBearAndPastLives()
        let bear = try #require(catalog.series.first)
        let tracked = try library.track(bear, status: .watching)

        try library.updateTrackedSeries(
            tracked,
            title: "The Bear (UK)",
            summary: "My own note.",
            seasons: [8, 10, 10],
            status: .finished,
            position: Position(season: 3, episode: 4),
            streamingService: "Disney+",
            nextEpisodeDate: nil
        )

        #expect(bear.title == "The Bear")
        #expect(bear.summary == "Carmy, a young fine-dining chef, comes home to Chicago.")
        #expect(bear.seasons.episodeCounts == [8, 10])
    }

    @Test func editingACopiedMovieLeavesTheCatalogEntryAlone() throws {
        let (library, catalog) = try theBearAndPastLives()
        let pastLives = try #require(catalog.movies.first)
        let tracked = try library.track(pastLives)

        try library.updateTrackedMovie(
            tracked,
            title: "Past Lives (2023)",
            summary: "Saw it twice.",
            streamingService: "Netflix",
            isWatched: true
        )

        #expect(pastLives.title == "Past Lives")
        #expect(pastLives.summary == "Childhood friends reunited in New York decades later.")
    }

    @Test func replacingTheWholeCatalogLeavesTheCopyAlone() throws {
        let (library, catalog) = try theBearAndPastLives()
        let bear = try #require(catalog.series.first)
        let pastLives = try #require(catalog.movies.first)
        try library.track(bear, status: .watching)
        try library.track(pastLives)

        try catalog.fill(from: .justSeverance)

        #expect(catalog.series.map(\.title) == ["Severance"])
        #expect(library.trackedSeries.map(\.title) == ["The Bear"])
        #expect(library.trackedSeries.first?.seasons.episodeCounts == [8, 10])
        #expect(library.trackedMovies.map(\.title) == ["Past Lives"])
    }

    @Test func aCopyOutlivesACatalogThatNoLongerCarriesIt() throws {
        let store = URL.temporaryDirectory.appending(path: "\(UUID()).store")
        let library = Library(container: try Library.container(at: store))
        let catalog = try Catalog.inMemory()
        try catalog.fill(from: .justTheBear)
        try library.track(try #require(catalog.series.first), status: .watching)

        try catalog.fill(from: .justSeverance)
        let relaunched = Library(container: try Library.container(at: store))

        #expect(relaunched.trackedSeries.map(\.title) == ["The Bear"])
    }

    // MARK: -

    /// A Library with nothing in it and a Catalog offering one series and one movie.
    private func theBearAndPastLives() throws -> (Library, Catalog) {
        let library = try Library.inMemory()
        let catalog = try Catalog.inMemory()
        try catalog.fill(from: .justTheBear)
        return (library, catalog)
    }
}

private extension CatalogSnapshot {
    /// A Catalog offering a series and a movie of the same name — the one case where the
    /// kind of entry, and not just the title, decides whether it is already tracked.
    static let dune = CatalogSnapshot(
        streamingServices: [],
        series: [
            CatalogSeriesSnapshot(
                externalId: "87739",
                title: "Dune",
                summary: "The Prophecy.",
                posterUrl: nil,
                seasons: [6]
            )
        ],
        movies: [
            CatalogMovieSnapshot(
                externalId: "438631",
                title: "Dune",
                summary: "Paul Atreides on Arrakis.",
                posterUrl: nil
            )
        ]
    )
}
