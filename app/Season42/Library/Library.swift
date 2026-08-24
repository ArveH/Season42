import Foundation
import SwiftData

/// The user's own collection of Tracked Series and Tracked Movies, and the single
/// owner of every rule about them. SwiftData lives entirely behind this facade —
/// views read the listings it publishes and call methods, and never touch a `ModelContext`.
@MainActor
@Observable
final class Library {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    /// Where every timestamp the Library stamps comes from; tests hand it a clock they move.
    private let now: @MainActor () -> Date

    /// Every series the user tracks, most recently added first.
    private(set) var trackedSeries: [TrackedSeries] = []

    /// Every movie the user tracks, most recently added first.
    private(set) var trackedMovies: [TrackedMovie] = []

    /// What the Library tab lists: everything the user tracks, series and movies
    /// interleaved, most recently added first.
    var entries: [LibraryEntry] {
        (trackedSeries.map(LibraryEntry.series) + trackedMovies.map(LibraryEntry.movie))
            .sorted { $0.addedAt > $1.addedAt }
    }

    /// The same listing, narrowed to the entries the user's Library Filter keeps.
    func entries(matching filter: LibraryFilter) -> [LibraryEntry] {
        entries.filter(filter.matches)
    }

    init(container: ModelContainer, now: @escaping @MainActor () -> Date = Date.init) {
        self.container = container
        self.now = now
        reload()
    }

    // MARK: - Tracking a series by hand

    /// Adds a hand-entered Tracked Series.
    ///
    /// - Parameter position: where the user already is, or nil if they have watched nothing yet.
    /// - Throws: `LibraryError` if any field is unusable; nothing is stored in that case.
    @discardableResult
    func addTrackedSeries(
        title: String,
        summary: String = "",
        seasons: Seasons,
        status: WatchStatus,
        position: Position? = nil,
        streamingService: String? = nil,
        nextEpisodeDate: Date? = nil
    ) throws -> TrackedSeries {
        let title = try validatedTitle(title, blankTitleIs: .seriesTitleIsBlank)
        try checkSeasons(seasons, hold: position)

        let series = TrackedSeries(
            title: title,
            summary: summary.trimmed,
            seasons: seasons,
            status: status,
            position: position,
            streamingService: streamingService?.trimmed.nilIfEmpty,
            nextEpisodeDate: nextEpisodeDate,
            addedAt: now()
        )
        context.insert(series)
        try context.save()
        reload()
        return series
    }

    /// The title as it should be stored — nothing an entry of either kind may be without.
    ///
    /// - Parameter blankTitleIs: what a title of nothing but whitespace means for the kind
    ///   of entry being stored, since the user is told about a series and a movie apart.
    private func validatedTitle(_ title: String, blankTitleIs error: LibraryError) throws -> String {
        let title = title.trimmed
        guard !title.isEmpty else { throw error }
        return title
    }

    /// Checks that these seasons are ones a Tracked Series can have, and that they hold
    /// the Position the user is at — whether the series is being added or edited.
    ///
    /// - Throws: `LibraryError` describing the first thing wrong.
    private func checkSeasons(_ seasons: Seasons, hold position: Position?) throws {
        guard !seasons.isEmpty else { throw LibraryError.seriesHasNoSeasons }
        if let season = seasons.firstSeasonWithoutEpisodes {
            throw LibraryError.seasonHasNoEpisodes(season: season)
        }
        if let position, !seasons.contains(position) {
            throw LibraryError.positionOutOfRange(position)
        }
    }

    // MARK: - Tracking a movie

    /// Adds a Tracked Movie, unwatched — which is to say, a watchlist entry.
    ///
    /// - Throws: `LibraryError.movieTitleIsBlank` if there is no title; nothing is stored then.
    @discardableResult
    func addTrackedMovie(
        title: String,
        summary: String = "",
        streamingService: String? = nil
    ) throws -> TrackedMovie {
        let title = try validatedTitle(title, blankTitleIs: .movieTitleIsBlank)

        let movie = TrackedMovie(
            title: title,
            summary: summary.trimmed,
            streamingService: streamingService?.trimmed.nilIfEmpty,
            addedAt: now()
        )
        context.insert(movie)
        try context.save()
        reload()
        return movie
    }

    /// Marks a movie watched, stamping when, or puts it back on the watchlist. As with a
    /// series un-watch, un-marking leaves the stamp alone: it records when the user last
    /// saw the movie, not whether they have — that is what `isWatched` is for.
    func setWatched(_ watched: Bool, on movie: TrackedMovie) {
        movie.isWatched = watched
        if watched {
            movie.watchedAt = now()
        }
        save()
    }

    // MARK: - Editing and deleting what is already tracked

    /// Rewrites a Tracked Series with what the user edited it to. An edit answers to every
    /// rule a new series does — including a season the original entry didn't have, which
    /// is the only way a returning series grows one — and a refused edit changes nothing.
    /// What the app stamps rather than the user types, `addedAt` and `lastWatchedAt`, is
    /// left alone: renaming a series is not watching it.
    ///
    /// Every field is spelled out because an edit rewrites the series whole: what is left
    /// out here is cleared, not kept.
    ///
    /// - Throws: `LibraryError` if any field is unusable; the series is untouched then.
    func updateTrackedSeries(
        _ series: TrackedSeries,
        title: String,
        summary: String,
        seasons: Seasons,
        status: WatchStatus,
        position: Position?,
        streamingService: String?,
        nextEpisodeDate: Date?
    ) throws {
        let title = try validatedTitle(title, blankTitleIs: .seriesTitleIsBlank)
        try checkSeasons(seasons, hold: position)

        series.title = title
        series.summary = summary.trimmed
        series.seasons = seasons
        series.status = status
        series.position = position
        series.streamingService = streamingService?.trimmed.nilIfEmpty
        series.nextEpisodeDate = nextEpisodeDate
        save()
    }

    /// Rewrites a Tracked Movie with what the user edited it to. As with a series, every
    /// field is spelled out: what is left out is cleared, not kept.
    ///
    /// - Parameter isWatched: the watched state to leave the movie in. Only a change of it
    ///   stamps the date, exactly as `setWatched(_:on:)` does, so an edit that renames the
    ///   movie never counts as watching it again.
    /// - Throws: `LibraryError.movieTitleIsBlank` if there is no title; nothing changes then.
    func updateTrackedMovie(
        _ movie: TrackedMovie,
        title: String,
        summary: String,
        streamingService: String?,
        isWatched: Bool
    ) throws {
        let title = try validatedTitle(title, blankTitleIs: .movieTitleIsBlank)

        movie.title = title
        movie.summary = summary.trimmed
        movie.streamingService = streamingService?.trimmed.nilIfEmpty
        if isWatched != movie.isWatched {
            setWatched(isWatched, on: movie)
        }
        save()
    }

    /// Removes a Library Entry for good. There is no undo and nothing is kept: the user
    /// asked for it to be gone.
    func delete(_ entry: LibraryEntry) {
        switch entry {
        case .series(let series): context.delete(series)
        case .movie(let movie): context.delete(movie)
        }
        save()
    }

    // MARK: - Watching

    /// What the Watching tab lists: series with status Watching, most recently watched
    /// first. Ones the user hasn't started come last, most recently added first.
    var watching: [TrackedSeries] {
        trackedSeries
            .filter { $0.status == .watching }
            .sorted { series, other in
                switch (series.lastWatchedAt, other.lastWatchedAt) {
                case let (watched?, otherWatched?) where watched != otherWatched:
                    watched > otherWatched
                case (.some, nil):
                    true
                case (nil, .some):
                    false
                default:
                    series.addedAt > other.addedAt
                }
            }
    }

    /// Advances the Position by one episode and stamps the watch, rolling over into the
    /// next season at a season boundary. Does nothing once the Position is at the last
    /// episode the series knows about — that is the app's cue to ask Finished or Waiting.
    func markNextEpisodeWatched(_ series: TrackedSeries) {
        guard let next = series.nextEpisode else { return }
        series.position = next
        series.lastWatchedAt = now()
        save()
    }

    /// Steps the Position back one episode, across a season boundary where needed, and
    /// back to nothing-watched at the very first episode. The watched-at stamp is left
    /// alone: correcting a mistap shouldn't move the series down the Watching list.
    func unwatchLastEpisode(_ series: TrackedSeries) {
        guard series.position != nil else { return }
        series.position = series.previousEpisode
        save()
    }

    /// Sets the status the user picked — including the answer to Finished-or-Waiting,
    /// which is what takes a series off the Watching tab.
    func setStatus(_ status: WatchStatus, on series: TrackedSeries) {
        series.status = status
        save()
    }

    // MARK: - Waiting

    /// What the Watching tab lists below `watching`: series with status Waiting, soonest
    /// Next Episode Date first. Ones without a date come last rather than disappearing,
    /// and series the dates can't separate come most recently added first.
    var waiting: [TrackedSeries] {
        trackedSeries
            .filter { $0.status == .waiting }
            .sorted { series, other in
                switch (series.nextEpisodeDate, other.nextEpisodeDate) {
                case let (date?, otherDate?) where date != otherDate:
                    date < otherDate
                case (.some, nil):
                    true
                case (nil, .some):
                    false
                default:
                    series.addedAt > other.addedAt
                }
            }
    }

    // MARK: - Loading

    /// Persists an edit to something already in the store. Unlike a rejected new entry,
    /// there is nothing here for the user to fix and no useful degraded mode, so a failing
    /// save leaves the in-memory Library as the user sees it and is not surfaced.
    private func save() {
        try? context.save()
        reload()
    }

    private func reload() {
        let newestSeriesFirst = FetchDescriptor<TrackedSeries>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        let newestMoviesFirst = FetchDescriptor<TrackedMovie>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        trackedSeries = (try? context.fetch(newestSeriesFirst)) ?? []
        trackedMovies = (try? context.fetch(newestMoviesFirst)) ?? []
    }
}

// MARK: - Containers

extension Library {
    /// The schema of everything the user owns. Catalog caching joins it in a later ticket.
    static let schema = Schema([TrackedSeries.self, TrackedMovie.self])

    /// The on-device store the app runs against.
    static func onDisk() throws -> Library {
        Library(container: try container(configuration: ModelConfiguration(schema: schema)))
    }

    /// A throwaway store for tests and previews.
    static func inMemoryContainer() throws -> ModelContainer {
        try container(
            configuration: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }

    static func inMemory(now: @escaping @MainActor () -> Date = Date.init) throws -> Library {
        Library(container: try inMemoryContainer(), now: now)
    }

    /// A store at an explicit location. Tests use it to reopen the same file the way a
    /// relaunch does; the app itself takes the default location via `onDisk()`.
    static func container(at url: URL) throws -> ModelContainer {
        try container(configuration: ModelConfiguration(schema: schema, url: url))
    }

    private static func container(configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(for: schema, configurations: configuration)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
