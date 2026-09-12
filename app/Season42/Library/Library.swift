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
    /// The calendar the Waiting order works a Release Slot's next occurrence out in.
    /// Injected beside `now` because that order turns on a weekday and a local midnight,
    /// and a test asserting the rollover cannot hang off the machine's own time zone.
    private let calendar: Calendar

    /// Every series the user tracks, most recently added first.
    private(set) var trackedSeries: [TrackedSeries] = []

    /// Every movie the user tracks, most recently added first.
    private(set) var trackedMovies: [TrackedMovie] = []

    /// Every Streaming Service the user has registered, alphabetically — a list read by
    /// name rather than scanned like a feed, so unlike the two above it is not by date.
    private(set) var streamingServices: [StreamingService] = []

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

    init(
        container: ModelContainer,
        now: @escaping @MainActor () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.container = container
        self.now = now
        self.calendar = calendar
        reload()
    }

    // MARK: - Tracking a series by hand

    /// Adds a hand-entered Tracked Series.
    ///
    /// - Parameter position: where the user already is, or nil if they have watched nothing yet.
    /// - Parameter poster: the Poster bytes copied off a search, or nil for a series entered by
    ///   hand — which is every series until a copy brings one.
    /// - Throws: `LibraryError` if any field is unusable; nothing is stored in that case.
    @discardableResult
    func addTrackedSeries(
        title: String,
        summary: String = "",
        poster: Data? = nil,
        seasons: Seasons,
        status: WatchStatus,
        position: Position? = nil,
        streamingService: StreamingService? = nil,
        nextEpisodeDate: Date? = nil,
        releaseSlot: ReleaseSlot? = nil
    ) throws -> TrackedSeries {
        let title = try validatedTitle(title, blankTitleIs: .seriesTitleIsBlank)
        try checkSeasons(seasons, hold: position)

        let series = TrackedSeries(
            title: title,
            summary: summary.trimmed,
            poster: poster,
            seasons: seasons,
            status: status,
            position: position,
            streamingService: streamingService,
            nextEpisodeDate: nextEpisodeDate,
            releaseSlot: releaseSlot,
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
    /// - Parameter poster: the Poster bytes copied off a search, or nil for a movie entered by
    ///   hand — which is every movie until a copy brings one.
    /// - Throws: `LibraryError.movieTitleIsBlank` if there is no title; nothing is stored then.
    @discardableResult
    func addTrackedMovie(
        title: String,
        summary: String = "",
        poster: Data? = nil,
        streamingService: StreamingService? = nil
    ) throws -> TrackedMovie {
        let title = try validatedTitle(title, blankTitleIs: .movieTitleIsBlank)

        let movie = TrackedMovie(
            title: title,
            summary: summary.trimmed,
            poster: poster,
            streamingService: streamingService,
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

    // MARK: - Registering the services the user watches on

    /// Registers a Streaming Service the user can then name on their entries.
    ///
    /// - Parameter logo: the Logo to adopt onto it, or nil to register it with none.
    /// - Throws: `LibraryError` if the name is blank or already registered; nothing is
    ///   stored in that case.
    @discardableResult
    func addStreamingService(name: String, logo: Data? = nil) throws -> StreamingService {
        let name = try validatedServiceName(name, keeping: nil)

        let service = StreamingService(name: name, logo: logo)
        context.insert(service)
        try context.save()
        reload()
        return service
    }

    /// Renames a Streaming Service. Because entries name the service itself rather than a
    /// copy of its name, every entry on it reads the new name at once.
    ///
    /// - Throws: `LibraryError` if the name is blank or belongs to another service; the
    ///   service is untouched then. Restyling a service's own name — "netflix" to
    ///   "Netflix" — is not a clash with itself.
    func renameStreamingService(_ service: StreamingService, to name: String) throws {
        service.name = try validatedServiceName(name, keeping: service)
        save()
    }

    /// Adopts a Logo onto a Streaming Service, or clears the one it has when handed nil.
    /// The name is untouched either way: the two are the user's to set apart, and nothing
    /// ever revisits an adopted Logo of its own accord (ADR-0007).
    func setLogo(_ logo: Data?, on service: StreamingService) {
        service.logo = logo
        save()
    }

    /// Removes a Streaming Service. Entries that named it are left naming none rather
    /// than deleted: cancelling a subscription says nothing about what the user tracks
    /// (ADR-0006). The UI is what tells them how many first — `entryCount` counts them.
    func deleteStreamingService(_ service: StreamingService) {
        context.delete(service)
        save()
    }

    /// The name as it should be stored.
    ///
    /// - Parameter keeping: the service being renamed, which is not a clash with itself,
    ///   or nil when a new one is being registered.
    /// - Throws: `LibraryError` describing what is wrong with the name.
    private func validatedServiceName(
        _ name: String,
        keeping service: StreamingService?
    ) throws -> String {
        let name = name.trimmed
        guard !name.isEmpty else { throw LibraryError.streamingServiceNameIsBlank }
        let clash = streamingServices.contains {
            $0 !== service && $0.name.caseInsensitiveCompare(name) == .orderedSame
        }
        guard !clash else { throw LibraryError.streamingServiceAlreadyExists(name: name) }
        return name
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
        poster: Data?,
        seasons: Seasons,
        status: WatchStatus,
        position: Position?,
        streamingService: StreamingService?,
        nextEpisodeDate: Date?,
        releaseSlot: ReleaseSlot?
    ) throws {
        let title = try validatedTitle(title, blankTitleIs: .seriesTitleIsBlank)
        try checkSeasons(seasons, hold: position)

        series.title = title
        series.summary = summary.trimmed
        series.poster = poster
        series.seasons = seasons
        series.status = status
        series.position = position
        series.streamingService = streamingService
        series.nextEpisodeDate = nextEpisodeDate
        series.releaseSlot = releaseSlot
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
        poster: Data?,
        streamingService: StreamingService?,
        isWatched: Bool
    ) throws {
        let title = try validatedTitle(title, blankTitleIs: .movieTitleIsBlank)

        movie.title = title
        movie.summary = summary.trimmed
        movie.poster = poster
        movie.streamingService = streamingService
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

    /// The Tracked Series whose Status is Watching, most recently added first as
    /// `trackedSeries` is and sorted no further: how the Watching tab lists them is
    /// `WatchingListing`'s to decide, not the Library's.
    var watching: [TrackedSeries] {
        trackedSeries.filter { $0.status == .watching }
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
    /// back to nothing-watched at the very first episode, and stamps Watched At as an
    /// advance does: the stamp says when the user last moved through the series, and this
    /// is moving through it. The stamp used to be left alone so a mistap would not move the
    /// series down the Watching list; the held-still Watching Order made that impossible,
    /// and the old rule was leaving a series stamped with a watch the user had taken back
    /// (ADR-0014).
    func unwatchLastEpisode(_ series: TrackedSeries) {
        guard series.position != nil else { return }
        series.position = series.previousEpisode
        series.lastWatchedAt = now()
        save()
    }

    /// Sets the status the user picked — including the answer to Finished-or-Waiting. That
    /// takes a series out of `watching`, and not off the Watching tab: the row lapses where
    /// it stands until the listing is re-taken, which is `WatchingListing`'s to decide.
    func setStatus(_ status: WatchStatus, on series: TrackedSeries) {
        series.status = status
        save()
    }

    // MARK: - Waiting

    /// What the Watching tab lists below `watching`: series with status Waiting, soonest
    /// back first. Ones that say nothing about when they are back come last rather than
    /// disappearing, and series that fall on the same day come most recently added first.
    ///
    /// A Release Slot ranks by the day it next lands on, among the dated ones, so a series
    /// airing tomorrow is not buried under one dated in March — even though its row says
    /// the recurrence and never that day (ADR-0016). Which means this listing is not a
    /// pure function of what is stored: two runs minutes apart can order differently, and
    /// the order turns over at local midnight, while nobody is looking.
    var waiting: [TrackedSeries] {
        let today = now()
        return trackedSeries
            .filter { $0.status == .waiting }
            .sorted { series, other in
                let day = series.dayNextBack(on: today, in: calendar)
                let otherDay = other.dayNextBack(on: today, in: calendar)
                return switch (day, otherDay) {
                case let (day?, otherDay?) where day != otherDay:
                    day < otherDay
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
        // Sorted here rather than by the fetch: a name is ordered the way the reader's
        // language orders it, which is what `localizedStandardCompare` knows and a
        // `SortDescriptor` on the store does not.
        streamingServices = ((try? context.fetch(FetchDescriptor<StreamingService>())) ?? [])
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

// MARK: - Containers

extension Library {
    /// The schema of everything the user owns — which, since ADR-0005, is everything
    /// the app stores.
    static let schema = Schema([TrackedSeries.self, TrackedMovie.self, StreamingService.self])

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

    static func inMemory(
        now: @escaping @MainActor () -> Date = Date.init,
        calendar: Calendar = .current
    ) throws -> Library {
        Library(container: try inMemoryContainer(), now: now, calendar: calendar)
    }

    /// A store at an explicit location. Tests use it to reopen the same file the way a
    /// relaunch does; the app itself takes the default location via `onDisk()`.
    static func container(at url: URL) throws -> ModelContainer {
        try container(configuration: ModelConfiguration(schema: schema, url: url))
    }

    /// Opens a store, and where the schema in the app can't open the one on disk, throws
    /// that store away and writes a fresh one in its place (ADR-0009). A store the app
    /// can't read holds nothing it can hand the user, so the only question is whether the
    /// app opens at all.
    private static func container(configuration: ModelConfiguration) throws -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            guard !configuration.isStoredInMemoryOnly else { throw error }
            discardStore(at: configuration.url)
            do {
                return try ModelContainer(for: schema, configurations: configuration)
            } catch let secondError {
                // Both errors, because the first one says why the store had to go and is
                // the only one worth reading — the second says only that a fresh store
                // couldn't be written either.
                throw LibraryStoreError(opening: error, andAfterDiscarding: secondError)
            }
        }
    }

    /// Deletes everything the store is kept in: the SQLite file, the write-ahead log,
    /// shared-memory and journal files SQLite keeps beside it, and the support directory
    /// SwiftData puts large values in. Leaving any of them behind is leaving the store
    /// half there, which is what the fresh open would then fail on.
    private static func discardStore(at url: URL) {
        let directory = url.deletingLastPathComponent()
        let store = url.lastPathComponent
        // `default.store` is kept company by `default.store-wal` and `.default_SUPPORT`,
        // so both the file's own name and its name without the extension are prefixes to
        // look for — and a leading dot is not part of either.
        let base = url.deletingPathExtension().lastPathComponent
        let beside = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        for file in beside {
            let name = file.lastPathComponent
            guard name == store
                || name.hasPrefix(store + "-")
                || name.drop(while: { $0 == "." }).hasPrefix(base + "_")
            else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }
}

/// What a Library can fail to open with once it has already thrown the store away: the
/// failure that condemned the store, and the one that stopped a fresh one taking its place.
struct LibraryStoreError: Error, CustomStringConvertible {
    let opening: any Error
    let andAfterDiscarding: any Error

    var description: String {
        "opening the store failed (\(opening)), and so did writing a fresh one "
            + "in its place (\(andAfterDiscarding))"
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
