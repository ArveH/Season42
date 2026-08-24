import Foundation

/// Why the Catalog has nothing to show. Unlike a `LibraryError` this is never the user's
/// mistake to fix — the Catalog is shared, read-only data — so the Catalog tab reports it
/// as a state it is in rather than as a rejected edit.
enum CatalogError: Error, Equatable, LocalizedError {
    /// The bundled snapshot is not in the app bundle. A build that ships without it is
    /// broken, not merely offline.
    case snapshotMissing

    var errorDescription: String? {
        switch self {
        case .snapshotMissing:
            "This build is missing its Catalog snapshot."
        }
    }
}
