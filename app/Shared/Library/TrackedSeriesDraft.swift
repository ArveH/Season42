import Foundation

/// Everything about a Tracked Series the user types, gathered into one value: what the
/// form holds and hands to `Library` whole, whether the series is being added or edited.
///
/// It carries no rules — every one of them is `Library`'s, and a draft that breaks one is
/// refused there. Nor is it what is stored: what the app stamps rather than the user
/// types, `addedAt` and `lastWatchedAt`, is no part of a draft, which is why an edit can
/// rewrite a series from one without disturbing either.
///
/// Because an edit rewrites the series whole, a field left at its default here is a field
/// cleared on the series — the same bargain the form makes when a toggle is turned off.
struct TrackedSeriesDraft {
    var title: String
    var summary: String = ""
    /// The Poster bytes copied off a search, or nil for a series entered by hand — which
    /// is every series until a copy brings one.
    var poster: Data?
    var seasons: Seasons
    var status: WatchStatus
    /// Where the user already is, or nil if they have watched nothing yet.
    var position: Position?
    /// Where the user watches it, or nil if they watch it nowhere they have registered.
    var streamingService: StreamingService?
    var nextEpisodeDate: Date?
    var releaseSlot: ReleaseSlot?
}
