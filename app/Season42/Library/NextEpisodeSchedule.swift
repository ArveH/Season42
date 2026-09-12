import Foundation

/// What a row that lists a Tracked Series says about when the next episode lands: the
/// series' Release Slot, or its Next Episode Date, or — as nil rather than a case here —
/// nothing at all.
///
/// The choice between the two is made once, by `TrackedSeries.nextEpisodeSchedule`, so
/// that no row can disagree with another about which one to show (ADR-0016).
enum NextEpisodeSchedule: Hashable, Sendable {
    case releaseSlot(ReleaseSlot)
    case nextEpisodeDate(Date)
}
