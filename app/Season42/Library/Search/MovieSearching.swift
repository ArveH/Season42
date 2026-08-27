import Foundation

/// Where a search for a movie gets its answers from. Two asks and no rules: which text to
/// search for, what an empty answer means and what a fetch that failed shows are all decisions
/// of `MovieSearch` — which is what lets every one of them be tested against a stub and leaves
/// only `BffClient` needing a network.
///
/// Two asks and not one, because opening a match is the second half of searching: the search
/// answers with ids, and an id is only good for asking the next question with. Two and not
/// three, because a movie carries no Poster yet — that is what makes this smaller than
/// `SeriesSearching` rather than a copy of it.
///
/// `Library` knows nothing of this. A search touches no store: the Library is the user's own
/// and a Movie Match is someone else's data, so the two only ever meet when the user copies.
protocol MovieSearching: Sendable {
    /// The movies whose titles match `text`, in the order the BFF serves them.
    ///
    /// - Throws: whatever went wrong reaching or reading the answer. Nothing matching is an
    ///   empty array, not an error — "nothing matched" and "I couldn't ask" are different
    ///   answers and the sheet shows them differently.
    func movies(matching text: String) async throws -> [MovieMatch]

    /// Everything the app shows about the movie with this id — the id a Movie Match carried,
    /// which is the only thing it is ever good for.
    ///
    /// Named for what it is about rather than as a plain `details(for:)`, as `SeriesSearching`'s
    /// `seriesDetails(for:)` is: `BffClient` answers both, and two asks that differ only in what
    /// they hand back are a thing to read twice at every call site.
    ///
    /// - Throws: whatever went wrong reaching or reading the answer, an id the BFF has no movie
    ///   for included. Unlike a search, there is no empty answer to tell apart from a failure:
    ///   the user tapped a match that was served moments ago, so anything other than the details
    ///   is the same "couldn't ask" to them.
    func movieDetails(for id: Int) async throws -> MovieDetails
}
