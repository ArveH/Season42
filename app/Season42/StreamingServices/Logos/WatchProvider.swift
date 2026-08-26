import Foundation

/// A service TMDB knows of, as the BFF answers a search with it: a name and TMDB's own
/// logo path. Never stored — it is what a search offers, not a thing the user owns. What
/// the user keeps is the bytes they adopt onto a Streaming Service (ADR-0007), and the
/// path is gone the moment they do.
struct WatchProvider: Decodable, Equatable, Sendable {
    let name: String

    /// TMDB's path for the logo, leading slash included, exactly as `/providers` serves
    /// it. Opaque to the app: the only thing it is ever used for is asking the BFF for
    /// the bytes behind it.
    let logoPath: String
}

/// A Watch Provider a search matched, with its logo already fetched — what a result row
/// draws and what adopting one takes its Logo from.
struct WatchProviderMatch: Identifiable, Equatable, Sendable {
    let provider: WatchProvider

    /// The logo image bytes, or nil where the BFF wouldn't serve them. A match without
    /// bytes still shows: its name is a true match, and the row draws the same `tv`
    /// stand-in a service with no Logo does.
    let logo: Data?

    var name: String { provider.name }

    /// TMDB's path, unique within a snapshot, which is what makes it the row's identity.
    var id: String { provider.logoPath }
}
