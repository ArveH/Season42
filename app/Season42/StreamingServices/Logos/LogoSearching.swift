import Foundation

/// Where a search for a Logo gets its answers from. Two asks and no rules: which text to
/// search for, what an empty answer means, and what happens to the bytes are all
/// `LogoSearch`'s decisions — which is what lets every one of them be tested against a
/// stub and leaves only `LogoApi` needing a network.
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

/// Why the logo service had nothing to give. Never the user's mistake to fix — they typed
/// a name, and a server they can't reach is not a name they got wrong — so nothing here
/// is shown verbatim: the sheet says one thing about a search it couldn't run, and that
/// saving without a Logo is still open.
enum LogoError: Error, Equatable {
    /// The server was reached but answered with something other than success.
    case notServed(status: Int)

    /// The server answered, but what came back isn't a list of Watch Providers.
    case notProviders
}
