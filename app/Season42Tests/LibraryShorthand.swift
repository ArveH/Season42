import Foundation
@testable import Season42

/// Adding and editing a Tracked Series the way a test wants to say it: one argument per
/// field, with a default for every field the test is not about. The app itself hands
/// `Library` a `TrackedSeriesDraft` the form gathered, which is the right shape for a
/// screen holding all nine fields at once and the wrong one for a test naming the two it
/// cares about.
///
/// An edit rewrites the entry whole, so leaving an argument out here clears that field,
/// exactly as clearing it in the form does.
@MainActor
extension Library {
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
        try addTrackedSeries(
            TrackedSeriesDraft(
                title: title,
                summary: summary,
                poster: poster,
                seasons: seasons,
                status: status,
                position: position,
                streamingService: streamingService,
                nextEpisodeDate: nextEpisodeDate,
                releaseSlot: releaseSlot
            )
        )
    }

    func edit(
        _ series: TrackedSeries,
        title: String,
        summary: String = "",
        poster: Data? = nil,
        seasons: Seasons,
        status: WatchStatus,
        position: Position? = nil,
        streamingService: StreamingService? = nil,
        nextEpisodeDate: Date? = nil,
        releaseSlot: ReleaseSlot? = nil
    ) throws {
        try updateTrackedSeries(
            series,
            to: TrackedSeriesDraft(
                title: title,
                summary: summary,
                poster: poster,
                seasons: seasons,
                status: status,
                position: position,
                streamingService: streamingService,
                nextEpisodeDate: nextEpisodeDate,
                releaseSlot: releaseSlot
            )
        )
    }

    func edit(
        _ movie: TrackedMovie,
        title: String,
        summary: String = "",
        poster: Data? = nil,
        streamingService: StreamingService? = nil,
        isWatched: Bool = false
    ) throws {
        try updateTrackedMovie(
            movie,
            title: title,
            summary: summary,
            poster: poster,
            streamingService: streamingService,
            isWatched: isWatched
        )
    }
}
