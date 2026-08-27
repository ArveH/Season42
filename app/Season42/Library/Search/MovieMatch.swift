import Foundation

/// A movie a search matched, as the BFF answers with it: an id and a title, and nothing else.
/// What a search lists, so that the user can tell which of several similar titles is theirs.
///
/// Someone else's data, never stored. The id is TMDB's and is only ever the thing the next
/// question is asked with — the Movie Details the user opens, and nothing else. Nothing in the
/// Library ever holds one (ADR-0002).
///
/// `Hashable` because it is what a row is pushed with: the match itself is the value the
/// navigation destination is keyed on, so nothing has to be looked up again on the way there.
struct MovieMatch: Decodable, Hashable, Identifiable, Sendable {
    /// TMDB's id, unique among matches, which is what makes it the row's identity.
    let id: Int

    /// A movie is titled where a series is named, and each is spelled the way the BFF spells it.
    let title: String
}
