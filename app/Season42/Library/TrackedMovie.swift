import Foundation
import SwiftData

/// A movie the user has added to their own data. It carries no Position and no Status:
/// a movie is watched or it isn't, and an unwatched one is simply a watchlist entry.
/// Created only through `Library`, which owns every rule about these fields.
@Model
final class TrackedMovie {
    var title: String
    /// What the movie is about, as the user typed it.
    var summary: String

    /// The Poster the user adopted with a copy, as image bytes, or nil where they adopted
    /// none. Bytes and not a link, and no TMDB id beside them: a Poster is the user's own
    /// once copied, nothing refreshes it, and the Library tab draws it with the BFF stopped,
    /// unreachable or never deployed (ADR-0013).
    var poster: Data?
    /// Where the user watches it, or nil if they watch it nowhere they have registered.
    var streamingService: StreamingService?
    var addedAt: Date
    /// Whether the user has seen it. An unwatched movie is a watchlist entry.
    var isWatched: Bool
    /// When the user last marked the movie watched, or nil if they never have. Un-marking
    /// leaves it alone, so a movie can be unwatched and still remember when it was seen —
    /// unlike a Tracked Series' Watched At, which an un-watch now stamps: this one is a
    /// fact about the film, and nothing orders by it (ADR-0014).
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

extension TrackedMovie {
    /// How the movie's watched state reads, as the parts a row joins: whether the user
    /// has seen it — keyed off `isWatched`, never the stamp — and, for one they un-marked,
    /// when they last saw it, since that stamp outlives the un-mark. A movie never watched
    /// has no date to report.
    var watchedState: [String] {
        guard let watchedAt else { return ["Not watched"] }
        let date = watchedAt.formatted(date: .abbreviated, time: .omitted)
        return isWatched ? ["Watched \(date)"] : ["Not watched", "last seen \(date)"]
    }
}
