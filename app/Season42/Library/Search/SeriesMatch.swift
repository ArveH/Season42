import Foundation

/// A series a search matched, as the BFF answers with it: an id and a name, and nothing else.
/// What a search lists, so that the user can tell which of several similar titles is theirs.
///
/// Someone else's data, never stored. The id is TMDB's and is only ever the thing the next
/// question is asked with — nothing in the Library ever holds one (ADR-0002).
struct SeriesMatch: Decodable, Equatable, Identifiable, Sendable {
    /// TMDB's id, unique among matches, which is what makes it the row's identity.
    let id: Int

    let name: String
}
