import Foundation

/// Where a search for a Logo gets its answers from. Two asks and no rules: which text to
/// search for, what an empty answer means, and what happens to the bytes are all
/// `LogoSearch`'s decisions — which is what lets every one of them be tested against a
/// stub and leaves only `BffClient` needing a network.
///
/// `Library` knows nothing of this. A search touches no store: the Library is the user's
/// own and a Watch Provider is someone else's data, so the two only ever meet when the
/// user saves.
protocol LogoSearching: Sendable {
    /// The Watch Providers whose names match `text`, in the order the BFF serves them.
    ///
    /// - Throws: whatever went wrong reaching or reading the answer. Nothing matching is
    ///   an empty array, not an error — "nothing matched" and "I couldn't ask" are
    ///   different answers and the sheet shows them differently.
    func providers(matching text: String) async throws -> [WatchProvider]

    /// The logo image bytes behind a Watch Provider's `logoPath`.
    ///
    /// - Throws: whatever went wrong reaching or reading them. A result whose logo can't
    ///   be fetched is still a result, so this failing costs a picture and nothing else.
    func logo(at path: String) async throws -> Data
}
