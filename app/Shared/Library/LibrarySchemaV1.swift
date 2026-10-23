import Foundation
import SwiftData

/// The Library's schema as it stood when it was first versioned: Tracked Series, Tracked
/// Movie and Streaming Service as they were before the schema was made iCloud-ready
/// (ADR-0023). A store written before the schema was versioned at all is this version too.
///
/// Frozen: a store on the user's device was written with it, and `LibraryMigrationPlan`
/// can only recognise that store while these classes hash exactly as they did. Nothing
/// here is ever edited, and nothing in the app reads these classes but the plan — the
/// behaviour the models have lives on the current version's names, in their own files.
/// The value types stored here (`Seasons`, `WatchStatus`, `Position`, `ReleaseSlot`) are
/// part of the hash too, and are frozen with them.
enum LibrarySchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [TrackedSeries.self, TrackedMovie.self, StreamingService.self]
    }

    @Model
    final class TrackedSeries {
        var title: String
        var summary: String
        var poster: Data?
        var seasons: Seasons
        var status: WatchStatus
        var position: Position?
        var streamingService: StreamingService?
        var nextEpisodeDate: Date?
        var releaseSlot: ReleaseSlot?
        var addedAt: Date
        var lastWatchedAt: Date?

        init(
            title: String,
            summary: String,
            poster: Data? = nil,
            seasons: Seasons,
            status: WatchStatus,
            position: Position?,
            streamingService: StreamingService?,
            nextEpisodeDate: Date?,
            releaseSlot: ReleaseSlot? = nil,
            addedAt: Date,
            lastWatchedAt: Date? = nil
        ) {
            self.title = title
            self.summary = summary
            self.poster = poster
            self.seasons = seasons
            self.status = status
            self.position = position
            self.streamingService = streamingService
            self.nextEpisodeDate = nextEpisodeDate
            self.releaseSlot = releaseSlot
            self.addedAt = addedAt
            self.lastWatchedAt = lastWatchedAt
        }
    }

    @Model
    final class TrackedMovie {
        var title: String
        var summary: String
        var poster: Data?
        var streamingService: StreamingService?
        var addedAt: Date
        var isWatched: Bool
        var watchedAt: Date?

        init(
            title: String,
            summary: String,
            poster: Data? = nil,
            streamingService: StreamingService?,
            addedAt: Date,
            isWatched: Bool = false,
            watchedAt: Date? = nil
        ) {
            self.title = title
            self.summary = summary
            self.poster = poster
            self.streamingService = streamingService
            self.addedAt = addedAt
            self.isWatched = isWatched
            self.watchedAt = watchedAt
        }
    }

    @Model
    final class StreamingService {
        var name: String
        var logo: Data?

        @Relationship(deleteRule: .nullify, inverse: \TrackedSeries.streamingService)
        var series: [TrackedSeries] = []

        @Relationship(deleteRule: .nullify, inverse: \TrackedMovie.streamingService)
        var movies: [TrackedMovie] = []

        init(name: String, logo: Data? = nil) {
            self.name = name
            self.logo = logo
        }
    }
}
