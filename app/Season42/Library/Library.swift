import Foundation
import SwiftData

/// The user's own collection of Tracked Series and Tracked Movies, and the single
/// owner of every rule about them. SwiftData lives entirely behind this facade —
/// views read `trackedSeries` and call methods, and never touch a `ModelContext`.
@MainActor
@Observable
final class Library {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    /// Everything the user tracks, most recently added first.
    private(set) var trackedSeries: [TrackedSeries] = []

    init(container: ModelContainer) {
        self.container = container
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
        let title = title.trimmed
        guard !title.isEmpty else { throw LibraryError.titleIsBlank }
        guard !seasons.isEmpty else { throw LibraryError.seriesHasNoSeasons }
        if let season = seasons.firstSeasonWithoutEpisodes {
            throw LibraryError.seasonHasNoEpisodes(season: season)
        }
        if let position, !seasons.contains(position) {
            throw LibraryError.positionOutOfRange(position)
        }

        let series = TrackedSeries(
            title: title,
            summary: summary.trimmed,
            seasons: seasons,
            status: status,
            position: position,
            streamingService: streamingService?.trimmed.nilIfEmpty,
            nextEpisodeDate: nextEpisodeDate,
            addedAt: Date()
        )
        context.insert(series)
        try context.save()
        reload()
        return series
    }

    // MARK: - Loading

    private func reload() {
        let newestFirst = FetchDescriptor<TrackedSeries>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        trackedSeries = (try? context.fetch(newestFirst)) ?? []
    }
}

// MARK: - Containers

extension Library {
    /// The schema of everything the user owns. Catalog caching joins it in a later ticket.
    static let schema = Schema([TrackedSeries.self])

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

    static func inMemory() throws -> Library {
        Library(container: try inMemoryContainer())
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
