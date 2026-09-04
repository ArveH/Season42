import Foundation

/// The Watching listing: the Tracked Series the Library says the user is watching, in the
/// Watching Order the user picked. Every rule about that order lives here — which of the
/// two is in force, how each one sorts, and where the choice is kept — and none of it in
/// `Library`, which hands the series over unsorted and has no say in how they are listed.
///
/// The order is live for now: marking an episode watched still moves a series. Holding it
/// still is the next step (ADR-0014), and this is the seam it will hang off.
@MainActor
@Observable
final class WatchingListing {
    private let library: Library
    private let defaults: UserDefaults

    /// Which Watching Order is in force. A preference about a listing rather than the
    /// user's own data, so it is kept in `UserDefaults` and never in the Library store
    /// (ADR-0005).
    var order: WatchingOrder {
        didSet { defaults.set(order.rawValue, forKey: Self.orderKey) }
    }

    /// The key the choice is remembered under.
    static let orderKey = "watchingOrder"

    init(library: Library, defaults: UserDefaults = .standard) {
        self.library = library
        self.defaults = defaults
        order = defaults.string(forKey: Self.orderKey)
            .flatMap(WatchingOrder.init(rawValue:)) ?? .lastWatched
    }

    /// The series the user is watching, in the order in force.
    var series: [TrackedSeries] {
        switch order {
        case .lastWatched: library.watching.sorted(by: Self.byLastWatched)
        case .title: library.watching.sorted(by: Self.byTitle)
        }
    }

    /// Most recently watched first. A Watched At stamp beats none, and series the stamps
    /// cannot separate come most recently added first.
    private static func byLastWatched(_ series: TrackedSeries, _ other: TrackedSeries) -> Bool {
        switch (series.lastWatchedAt, other.lastWatchedAt) {
        case let (watched?, otherWatched?) where watched != otherWatched:
            watched > otherWatched
        case (.some, nil):
            true
        case (nil, .some):
            false
        default:
            series.addedAt > other.addedAt
        }
    }

    /// Alphabetical the way the reader's language orders it: case and diacritics behave
    /// as a reader expects, and a leading "The" is not stripped — "The Bear" files under
    /// T (ADR-0014). Titles the comparison cannot separate come most recently added first.
    private static func byTitle(_ series: TrackedSeries, _ other: TrackedSeries) -> Bool {
        switch series.title.localizedStandardCompare(other.title) {
        case .orderedAscending: true
        case .orderedDescending: false
        case .orderedSame: series.addedAt > other.addedAt
        }
    }
}
