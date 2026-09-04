import Foundation
import SwiftData

/// The Watching listing: the Tracked Series the Library says the user is watching, in the
/// Watching Order the user picked. Every rule about that order lives here — which of the
/// two is in force, how each one sorts, where the choice is kept, and when the listing is
/// allowed to move — and none of it in `Library`, which hands the series over unsorted and
/// has no say in how they are listed.
///
/// The order is held still (ADR-0014). It is taken as a snapshot and re-taken only when the
/// user picks an order or arrives on the tab; marking an episode watched, taking one back
/// and editing a series all leave every row where it is.
@MainActor
@Observable
final class WatchingListing {
    private let library: Library
    private let defaults: UserDefaults

    /// Which Watching Order is in force. A preference about a listing rather than the
    /// user's own data, so it is kept in `UserDefaults` and never in the Library store
    /// (ADR-0005). Picking one is one of the two moments the snapshot is re-taken.
    var order: WatchingOrder {
        didSet {
            defaults.set(order.rawValue, forKey: Self.orderKey)
            retake()
        }
    }

    /// The key the choice is remembered under.
    static let orderKey = "watchingOrder"

    /// The snapshot: which series are listed and in what order, as identifiers rather than
    /// the series themselves. Identifiers are re-resolved against the Library on every
    /// read, so a series deleted while the listing is held still simply fails to resolve
    /// and drops out, where holding the model object would mean drawing or crashing on a
    /// deleted one. Position is what is frozen; existence never is.
    private var snapshot: [PersistentIdentifier] = []

    init(library: Library, defaults: UserDefaults = .standard) {
        self.library = library
        self.defaults = defaults
        order = defaults.string(forKey: Self.orderKey)
            .flatMap(WatchingOrder.init(rawValue:)) ?? .lastWatched
        retake()
    }

    /// The series the user is watching, in the order the snapshot holds them.
    var series: [TrackedSeries] {
        let watching = Dictionary(
            library.watching.map { ($0.persistentModelID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return snapshot.compactMap { watching[$0] }
    }

    /// Re-takes the snapshot from what the Library holds now, in the order in force. The
    /// view calls this when the user arrives on the tab from another tab — and not when a
    /// sheet opened over the tab closes again, which is not an arrival: with an Edit
    /// button on every row, coming back from the form to a re-sorted list would be a
    /// smaller version of the defect the freeze exists to fix (ADR-0014).
    func retake() {
        let sorted = switch order {
        case .lastWatched: library.watching.sorted(by: Self.byLastWatched)
        case .title: library.watching.sorted(by: Self.byTitle)
        }
        snapshot = sorted.map(\.persistentModelID)
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
