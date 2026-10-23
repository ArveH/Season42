// PROTOTYPE — the CloudKit spike for #137. Throwaway; never merged to main.
//
// The three Library models, reshaped the way ADR-0022 says V2 will be: every stored property
// defaulted or optional, the service's to-many relationships optional, no unique constraints,
// Posters and Logos in external storage. Named as the app names them so the CloudKit record
// types look like the real ones will. The value types they store (`Seasons`, `Position`,
// `ReleaseSlot`, `WatchStatus`) are the app's own files, compiled in unchanged.

import Foundation
import SwiftData

@Model
final class TrackedSeries {
    var title: String = ""
    var summary: String = ""
    @Attribute(.externalStorage) var poster: Data?
    // Not `= [1]`: SwiftData reads an array-literal default as an array, not a Seasons, and
    // traps at launch with "Composite Coder only supports Keyed Container". Spike finding.
    var seasons: Seasons = Seasons(episodeCounts: [1])
    var status: WatchStatus = WatchStatus.planned
    var position: Position?
    var streamingService: StreamingService?
    var nextEpisodeDate: Date?
    var releaseSlot: ReleaseSlot?
    var addedAt: Date = Date.distantPast
    var lastWatchedAt: Date?

    init(
        title: String, summary: String, poster: Data?, seasons: Seasons, status: WatchStatus,
        position: Position?, streamingService: StreamingService?, nextEpisodeDate: Date?,
        releaseSlot: ReleaseSlot?, addedAt: Date, lastWatchedAt: Date?
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
    var title: String = ""
    var summary: String = ""
    @Attribute(.externalStorage) var poster: Data?
    var streamingService: StreamingService?
    var addedAt: Date = Date.distantPast
    var isWatched: Bool = false
    var watchedAt: Date?

    init(
        title: String, summary: String, poster: Data?, streamingService: StreamingService?,
        addedAt: Date, isWatched: Bool, watchedAt: Date?
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
    var name: String = ""
    @Attribute(.externalStorage) var logo: Data?

    @Relationship(deleteRule: .nullify, inverse: \TrackedSeries.streamingService)
    var series: [TrackedSeries]? = []

    @Relationship(deleteRule: .nullify, inverse: \TrackedMovie.streamingService)
    var movies: [TrackedMovie]? = []

    init(name: String, logo: Data?) {
        self.name = name
        self.logo = logo
    }
}
