import Foundation

/// Where a search for a movie gets its answers from. Three asks and no rules: which text to
/// search for, what an empty answer means, what a fetch that failed shows and what becomes of
/// the poster bytes are all decisions of `MovieSearch` — which is what lets every one of them be
/// tested against a stub and leaves only `BffClient` needing a network.
///
/// Three asks and not one, because opening a match is the second half of searching: the search
/// answers with ids, and an id is only good for asking the next two questions with — the
/// details, and the poster the details said was there. The same three `SeriesSearching` asks,
/// for the other kind of Library Entry, and separate from it because they are separate asks of
/// the BFF.
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

    /// The poster image bytes of the movie with this id — the same id the details were read
    /// with, because there is no path to ask with and the app never sees one (ADR-0012).
    ///
    /// - Throws: whatever went wrong reaching or reading them, a movie TMDB has no poster for
    ///   included. A detail screen without its poster is still a detail screen, so this failing
    ///   costs a picture and nothing else: everything else still copies.
    func moviePoster(for id: Int) async throws -> Data
}
