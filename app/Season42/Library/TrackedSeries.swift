import Foundation
import SwiftData

/// A series the user has added to their own data. Created only through `Library`,
/// which is the sole owner of the rules these fields have to satisfy.
@Model
final class TrackedSeries {
    var title: String
    /// What the series is about, as the user typed it.
    var summary: String
    var seasons: Seasons
    var status: WatchStatus
    var position: Position?
    var streamingService: String?
    var nextEpisodeDate: Date?
    var addedAt: Date

    init(
        title: String,
        summary: String,
        seasons: Seasons,
        status: WatchStatus,
        position: Position?,
        streamingService: String?,
        nextEpisodeDate: Date?,
        addedAt: Date
    ) {
        self.title = title
        self.summary = summary
        self.seasons = seasons
        self.status = status
        self.position = position
        self.streamingService = streamingService
        self.nextEpisodeDate = nextEpisodeDate
        self.addedAt = addedAt
    }
}
