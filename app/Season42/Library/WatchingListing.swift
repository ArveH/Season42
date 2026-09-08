import Foundation
import SwiftData

/// The Watching listing: the Tracked Series the Library says the user is watching, in the
/// Watching Order the user picked, with the Waiting listing below it. Every rule about that
/// order lives here — which of the two is in force, how each one sorts, where the choice is
/// kept, when the listing is allowed to move, and which rows have lapsed — and none of it
/// in `Library`, which hands the series over unsorted and has no say in how they are listed.
///
/// The order is held still (ADR-0014). It is taken as a snapshot and re-taken only when the
/// user picks an order, arrives on the tab, or pulls the listing down; marking an episode
/// watched, taking one back and editing a series all leave every row where it is. So does
/// changing its Status: a series whose Status stops being Watching stays in the listing as a
/// Lapsed Row until the next re-take sweeps it, so a mis-tapped Finished is undone on the
/// row it happened on. A series whose Status becomes Watching while the tab is held still
/// is appended below the snapshot rather than left off the tab, and the next re-take sorts
/// it in.
///
/// The tab's Library Filter lives here too, its own and not the Library tab's. It narrows
/// both listings as a view over them: rows that don't match are hidden, nothing moves,
/// nothing is re-taken and nothing is written, so clearing the text shows the same rows
/// in the same places.
@MainActor
@Observable
final class WatchingListing {
    private let library: Library
    private let defaults: UserDefaults

    /// Which Watching Order is in force. A preference about a listing rather than the
    /// user's own data, so it is kept in `UserDefaults` and never in the Library store
    /// (ADR-0005). Picking one is one of the three moments the snapshot is re-taken.
    var order: WatchingOrder {
        didSet {
            defaults.set(order.rawValue, forKey: Self.orderKey)
            retake()
        }
    }

    /// The key the choice is remembered under.
    static let orderKey = "watchingOrder"

    /// How the user has narrowed the tab: the Watching tab's own Library Filter, of which
    /// the tab offers the search text alone for now. Settable, so the view binds the
    /// search bar straight to it and holds no filter of its own. Not remembered between
    /// launches — a search is something the user is doing, not a preference — and left
    /// alone by a re-take, since picking an order or arriving on the tab is not clearing
    /// a search.
    var filter = LibraryFilter()

    /// The snapshot: which series are listed and in what order, as identifiers rather than
    /// the series themselves. Identifiers are re-resolved against the Library on every
    /// read, so a series deleted while the listing is held still simply fails to resolve
    /// and drops out, where holding the model object would mean drawing or crashing on a
    /// deleted one. Position is what is frozen; existence never is. Every Library
    /// mutation saves, so the identifiers are permanent by the time they are taken.
    private var snapshot: [PersistentIdentifier] = []

    init(library: Library, defaults: UserDefaults = .standard) {
        self.library = library
        self.defaults = defaults
        order = defaults.string(forKey: Self.orderKey)
            .flatMap(WatchingOrder.init(rawValue:)) ?? .lastWatched
        retake()
    }

    /// The Watching listing as the tab draws it: `held` narrowed by the filter. A Lapsed
    /// Row and a joined row match like any other, on their title.
    var series: [TrackedSeries] {
        held.filter { filter.matches(.series($0)) }
    }

    /// The Waiting listing as the tab draws it: `heldWaiting` narrowed by the filter.
    var waiting: [TrackedSeries] {
        heldWaiting.filter { filter.matches(.series($0)) }
    }

    /// Whether there is nothing to list at all, whatever the filter says: no Watching
    /// series, no Waiting series and no Lapsed Row. What "Nothing on the go" keys off,
    /// as against a filter that happens to hide every row.
    var isEmpty: Bool {
        held.isEmpty && heldWaiting.isEmpty
    }

    /// The series the snapshot holds, in its order — the ones the user is watching, and any
    /// Lapsed Rows among them — followed by every Watching series the snapshot does not
    /// hold. The snapshot is resolved against every Tracked Series rather than only the
    /// Watching ones, because a series whose Status has changed since the snapshot was
    /// taken is still listed — it lapses rather than leaving, however the Status changed
    /// (ADR-0014). A deleted series is not among them: it fails to resolve and is gone.
    ///
    /// The tail is the mirror case: a series whose Status became Watching while the tab was
    /// held still, from the Edit sheet on a Waiting row. Left off, it would vanish from the
    /// tab altogether — gone from the Waiting listing at once and not yet in the snapshot —
    /// so it is appended, in the order in force, where nothing above it has to move. Like
    /// a Lapsed Row it is derived and never stored, and unlike one it is not held: set back
    /// to Waiting it returns to the Waiting listing at once, and the next re-take sorts it
    /// in with the rest.
    private var held: [TrackedSeries] {
        let tracked = Dictionary(
            uniqueKeysWithValues: library.trackedSeries.map { ($0.persistentModelID, $0) }
        )
        let heldIDs = Set(snapshot)
        let joined = library.watching
            .filter { !heldIDs.contains($0.persistentModelID) }
            .sorted(by: comparator)
        return snapshot.compactMap { tracked[$0] } + joined
    }

    /// Whether a listed series is a Lapsed Row: still drawn because the snapshot holds it,
    /// though its Status is no longer Watching. Derived and never stored — nothing is
    /// written when a row lapses, and setting the Status back to Watching is the whole of
    /// un-lapsing it.
    func isLapsed(_ series: TrackedSeries) -> Bool {
        series.status != .watching && snapshot.contains(series.persistentModelID)
    }

    /// The Waiting listing below the Watching one: the Library's, in the Library's order,
    /// less any series the snapshot still holds. A row that has just lapsed to Waiting is
    /// drawn once, where it stands, and not again below until a re-take sweeps it there.
    private var heldWaiting: [TrackedSeries] {
        let heldIDs = Set(snapshot)
        return library.waiting.filter { !heldIDs.contains($0.persistentModelID) }
    }

    /// Re-takes the snapshot from what the Library holds now, in the order in force. The
    /// view calls this when the user arrives on the tab from another tab, and when they
    /// pull the listing down — and not when a sheet opened over the tab closes again,
    /// which is not an arrival: with an Edit button on every row, coming back from the
    /// form to a re-sorted list would be a smaller version of the defect the freeze exists
    /// to fix (ADR-0014).
    func retake() {
        snapshot = library.watching.sorted(by: comparator).map(\.persistentModelID)
    }

    /// How the order in force sorts two series.
    private var comparator: (TrackedSeries, TrackedSeries) -> Bool {
        switch order {
        case .lastWatched: Self.byLastWatched
        case .title: Self.byTitle
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
