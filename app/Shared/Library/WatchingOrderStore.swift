import Foundation

/// Where the Watching Order is kept between launches: read the stored raw value, write one.
/// `WatchingListing` holds one of these rather than a particular store, so where the choice
/// lives is the app's to say — iCloud's key-value store on the iPhone, shared with the
/// Watch App (ADR-0022) — and a test passes one in memory.
///
/// It stores the raw value and nothing more. Turning that into a `WatchingOrder`, and
/// falling back when it can't be, is the listing's rule and stays with the listing.
protocol WatchingOrderStore {
    /// The raw value last written, or nil when nothing has been.
    func read() -> String?

    /// Keeps `rawValue` as the choice, in place of whatever was kept before.
    func write(_ rawValue: String)
}
