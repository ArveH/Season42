import Foundation

/// The details of one Series Match being fetched, and everything the detail screen is holding
/// while that happens: which match was opened, and where the fetch has got to. Every decision
/// about the fetch lives here — that the match's name is on screen before anything has arrived,
/// that a failure is retried as the same ask — so the screen renders this and decides nothing,
/// and all of it is tested against a stub.
///
/// Nothing here reaches a store. A Series Match and its details are someone else's data, and
/// the Library only ever holds what the user copied.
@MainActor
@Observable
final class SeriesDetailsRequest {
    /// Where the fetch has got to. There is no "nothing yet": the screen is pushed by a tap
    /// that is itself the ask, so it opens already loading.
    enum State: Equatable {
        /// The details are on their way. What the screen spins on.
        case loading

        /// What the BFF answered with.
        case loaded(SeriesDetails)

        /// The details couldn't be fetched at all — the BFF is unreachable, has no series
        /// under that id, or answered with something that isn't a Series Details. All one
        /// thing to the user: they tapped a match the search served moments ago, and there is
        /// nothing here for them to correct except to try again.
        case failed
    }

    /// The match this was opened from. Its name is what the screen shows while the details are
    /// still owed, so the user can see which of several similar titles they tapped.
    let match: SeriesMatch

    private(set) var state: State = .loading

    private let series: any SeriesSearching

    init(for match: SeriesMatch, series: any SeriesSearching) {
        self.match = match
        self.series = series
    }

    /// Fetches the details of the match. Run once when the screen appears, and again by the
    /// Retry the failure offers — nothing about the match changes, so it is the same ask every
    /// time, and there is no stale answer to guard against.
    ///
    /// Never throws: a fetch that can't be run is a state the screen shows. The search
    /// underneath is untouched, so Back still lists what it matched.
    func load() async {
        state = .loading
        do {
            state = .loaded(try await series.details(for: match.id))
        } catch {
            state = .failed
        }
    }
}
