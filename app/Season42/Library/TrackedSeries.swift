import Foundation
import SwiftData

/// A series the user has added to their own data. Created only through `Library`,
/// which is the sole owner of the rules these fields have to satisfy.
@Model
final class TrackedSeries {
    var title: String
    /// What the series is about, as the user typed it.
    var summary: String

    /// The Poster the user adopted with a copy, as image bytes, or nil where they adopted
    /// none. Bytes and not a link, and no TMDB id beside them: a Poster is the user's own
    /// once copied, nothing refreshes it, and the Library and Watching tabs draw it with the
    /// BFF stopped, unreachable or never deployed (ADR-0013).
    var poster: Data?

    var seasons: Seasons
    var status: WatchStatus
    var position: Position?
    /// Where the user watches it, or nil if they watch it nowhere they have registered.
    var streamingService: StreamingService?
    var nextEpisodeDate: Date?
    var addedAt: Date
    /// Watched At: when the user last moved through the series, by marking an episode
    /// watched or by taking one back, or nil if they never have. The name is narrower than
    /// what it holds: this is not when an episode was last seen (ADR-0014).
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
        self.addedAt = addedAt
        self.lastWatchedAt = lastWatchedAt
    }
}

extension TrackedSeries {
    /// The episode a "watched it" tap would mark: the first one when nothing is watched
    /// yet, the next one otherwise. Nil once the Position sits at the last episode of the
    /// last season the user has entered — there is nothing further to offer.
    var nextEpisode: Position? {
        guard let position else {
            let first = Position(season: 1, episode: 1)
            return seasons.contains(first) ? first : nil
        }
        return seasons.episode(after: position)
    }

    /// The episode an un-watch would step back to, or nil when the Position is at the very
    /// first episode — there, un-watching leaves the series with nothing watched at all.
    var previousEpisode: Position? {
        position.flatMap { seasons.episode(before: $0) }
    }

    /// The Position is at the last episode this series knows about, so instead of another
    /// "watched it" the app asks whether the series is Finished or Waiting for more.
    var isAtLastKnownEpisode: Bool {
        position != nil && nextEpisode == nil
    }
}
