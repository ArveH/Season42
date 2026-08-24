import Foundation

/// Where a Sync gets the Catalog from. Fetching one document is the whole of it: what to
/// do with what comes back — replace the cache, keep it, say nothing — is `Catalog`'s
/// decision, which is what lets every rule of Sync be tested against a stub and leaves
/// only `CatalogApi` needing a network.
protocol CatalogFetching: Sendable {
    /// The Catalog as it is served right now.
    ///
    /// - Throws: whatever went wrong reaching or reading it. Nothing partial comes back:
    ///   a snapshot is the Catalog whole or it is an error.
    func fetchSnapshot() async throws -> CatalogSnapshot
}
