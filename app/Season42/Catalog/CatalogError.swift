import Foundation

/// Why the Catalog has nothing to show. Unlike a `LibraryError` this is never the user's
/// mistake to fix — the Catalog is shared, read-only data — so the Catalog tab reports it
/// as a state it is in rather than as a rejected edit.
enum CatalogError: Error, Equatable, LocalizedError {
    /// The bundled snapshot is not in the app bundle. A build that ships without it is
    /// broken, not merely offline.
    case snapshotMissing

    /// The API was reached but answered a Sync with something other than a Catalog.
    case notServed(status: Int)

    /// The API answered, but what came back doesn't decode as a Catalog.
    case notACatalog

    var errorDescription: String? {
        switch self {
        case .snapshotMissing:
            "This build is missing its Catalog snapshot."
        case .notServed(let status):
            "The Catalog service answered with \(status)."
        case .notACatalog:
            "The Catalog service answered with something that isn't a Catalog."
        }
    }
}
