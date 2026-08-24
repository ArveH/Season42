import Foundation
import SwiftData

/// The device's cached copy of the shared Catalog, and the single owner of how it is
/// filled. It stands next to `Library` and never overlaps it: the Catalog is read-only
/// data every installation shares, the Library is the user's own, and the two live in
/// separate stores so that replacing the whole Catalog can never touch what the user
/// tracks (ADR-0001). Views read the listings published here and never a `ModelContext`.
@MainActor
@Observable
final class Catalog {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    /// The services the Catalog knows about, in the order it serves them.
    private(set) var streamingServices: [CatalogStreamingService] = []

    /// The series the Catalog offers, in the order it serves them.
    private(set) var series: [CatalogSeries] = []

    /// The movies the Catalog offers, in the order it serves them — which is the Catalog's
    /// call to make, not the cache's.
    private(set) var movies: [CatalogMovie] = []

    /// Whether there is nothing cached at all: a first launch, or a build whose snapshot
    /// wouldn't load. What the Catalog tab keys its empty state off.
    var isEmpty: Bool {
        streamingServices.isEmpty && series.isEmpty && movies.isEmpty
    }

    /// Whether a Sync the user asked for is in flight, so the Catalog tab can show it.
    /// A launch's Sync never sets it: one nobody asked for is one nobody is waiting on,
    /// and a tab that spins by itself on every launch is not silent.
    private(set) var isSyncing = false

    init(container: ModelContainer) {
        self.container = container
        reload()
    }

    /// Fills a first launch's empty cache from the snapshot the app ships with, and
    /// leaves a cache that already has something in it alone — a later launch reads what
    /// was cached, not the bundle.
    ///
    /// - Throws: `CatalogError.snapshotMissing`, or a decoding or store error. Nothing is
    ///   cached in that case and the Catalog stays empty.
    func fillFromBundledSnapshotIfEmpty() throws {
        guard isEmpty else { return }
        try fill(from: CatalogSnapshot.bundled())
    }

    /// Makes the cache say exactly what `snapshot` says: everything cached goes and the
    /// snapshot's entries take its place, in the order it serves them. The Catalog is a
    /// copy of shared data, not a merge of it — and the user's Library is in another
    /// store, so nothing they own is in reach of this.
    ///
    /// - Throws: a store error, with the cache left as the store last saved it.
    func fill(from snapshot: CatalogSnapshot) throws {
        try context.delete(model: CatalogStreamingService.self)
        try context.delete(model: CatalogSeries.self)
        try context.delete(model: CatalogMovie.self)

        for (order, service) in snapshot.streamingServices.enumerated() {
            context.insert(
                CatalogStreamingService(
                    externalId: service.externalId,
                    name: service.name,
                    order: order
                )
            )
        }
        for (order, series) in snapshot.series.enumerated() {
            context.insert(
                CatalogSeries(
                    externalId: series.externalId,
                    title: series.title,
                    summary: series.summary,
                    posterUrl: series.posterUrl,
                    seasons: series.seasons,
                    order: order
                )
            )
        }
        for (order, movie) in snapshot.movies.enumerated() {
            context.insert(
                CatalogMovie(
                    externalId: movie.externalId,
                    title: movie.title,
                    summary: movie.summary,
                    posterUrl: movie.posterUrl,
                    order: order
                )
            )
        }

        try context.save()
        reload()
    }

    // MARK: - Sync

    /// Replaces the cached Catalog with what the API serves right now. A Sync that gets
    /// as far as an answer says exactly what that answer says, an empty Catalog included;
    /// one that doesn't get that far changes nothing, so the cache the user had is still
    /// the cache they have. Either way the Library is in another store and out of reach
    /// (ADR-0001), and the copies in it are the user's own (ADR-0002) — no outcome of a
    /// Sync touches a Tracked Series or a Tracked Movie.
    ///
    /// - Throws: whatever fetching threw, or a store error. Nothing the API didn't answer
    ///   with is cached, so a Sync that throws leaves what was cached to browse.
    func sync(using api: any CatalogFetching) async throws {
        isSyncing = true
        defer { isSyncing = false }
        try await replaceCache(using: api)
    }

    /// A Sync nobody asked for — what a launch does. There is nothing for the user to fix
    /// about an API they can't reach and nothing they were waiting to see, so it says
    /// nothing while it runs and nothing when it fails: the cache stays as it is. What
    /// the user asked for themselves is `sync(using:)`, which shows both.
    func syncQuietly(using api: any CatalogFetching) async {
        try? await replaceCache(using: api)
    }

    private func replaceCache(using api: any CatalogFetching) async throws {
        try fill(from: await api.fetchSnapshot())
    }

    /// Reads every listing back in the order the Catalog served it — the `order` each
    /// entry was cached with.
    private func reload() {
        let servicesAsServed = FetchDescriptor<CatalogStreamingService>(
            sortBy: [SortDescriptor(\.order)]
        )
        let seriesAsServed = FetchDescriptor<CatalogSeries>(sortBy: [SortDescriptor(\.order)])
        let moviesAsServed = FetchDescriptor<CatalogMovie>(sortBy: [SortDescriptor(\.order)])
        streamingServices = (try? context.fetch(servicesAsServed)) ?? []
        series = (try? context.fetch(seriesAsServed)) ?? []
        movies = (try? context.fetch(moviesAsServed)) ?? []
    }
}

// MARK: - Containers

extension Catalog {
    /// The schema of the cached Catalog. It shares no entity with `Library.schema`: what
    /// the user owns and what the Catalog serves are different things, kept apart.
    static let schema = Schema([CatalogStreamingService.self, CatalogSeries.self, CatalogMovie.self])

    /// The on-device cache the app runs against, in its own store file beside the
    /// Library's.
    static func onDisk() throws -> Catalog {
        Catalog(container: try container(configuration: ModelConfiguration(storeName, schema: schema)))
    }

    /// A throwaway cache for tests and previews.
    static func inMemoryContainer() throws -> ModelContainer {
        try container(
            configuration: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }

    static func inMemory() throws -> Catalog {
        Catalog(container: try inMemoryContainer())
    }

    /// A cache at an explicit location. Tests use it to reopen the same file the way a
    /// relaunch does; the app itself takes the default location via `onDisk()`.
    static func container(at url: URL) throws -> ModelContainer {
        try container(configuration: ModelConfiguration(schema: schema, url: url))
    }

    /// Names the cache's own store file, so it can never be the Library's.
    private static let storeName = "Catalog"

    private static func container(configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(for: schema, configurations: configuration)
    }
}
