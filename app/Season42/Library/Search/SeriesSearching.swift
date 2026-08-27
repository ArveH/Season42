import Foundation

/// Where a search for a series gets its answers from. Three asks and no rules: which text to
/// search for, what an empty answer means, what a fetch that failed shows and what becomes of
/// the poster bytes are all decisions of `SeriesSearch` — which is what lets every one of them
/// be tested against a stub and leaves only `BffClient` needing a network.
///
/// Three asks and not one, because opening a match is the second half of searching: the search
/// answers with ids, and an id is only good for asking the next two questions with — the
/// details, and the poster the details said was there. Separate from `LogoSearching` rather
/// than folded in with it, so that the logo stub beside it is untouched by anything that
/// happens here.
///
/// `Library` knows nothing of this. A search touches no store: the Library is the user's own
/// and a Series Match is someone else's data, so the two only ever meet when the user copies.
protocol SeriesSearching: Sendable {
    /// The series whose names match `text`, in the order the BFF serves them.
    ///
    /// - Throws: whatever went wrong reaching or reading the answer. Nothing matching is an
    ///   empty array, not an error — "nothing matched" and "I couldn't ask" are different
    ///   answers and the sheet shows them differently.
    func series(matching text: String) async throws -> [SeriesMatch]

    /// Everything the app shows about the series with this id — the id a Series Match carried,
    /// which is the only thing it is ever good for.
    ///
    /// Named for what it is about rather than as a plain `details(for:)`, because `BffClient`
    /// answers this and `MovieSearching`'s alike, and two asks that differ only in what they
    /// hand back are a thing to read twice at every call site.
    ///
    /// - Throws: whatever went wrong reaching or reading the answer, an id the BFF has no
    ///   series for included. Unlike a search, there is no empty answer to tell apart from a
    ///   failure: the user tapped a match that was served moments ago, so anything other than
    ///   the details is the same "couldn't ask" to them.
    func seriesDetails(for id: Int) async throws -> SeriesDetails

    /// The poster image bytes of the series with this id — the same id the details were read
    /// with, because there is no path to ask with and the app never sees one (ADR-0012).
    ///
    /// - Throws: whatever went wrong reaching or reading them, a series TMDB has no poster for
    ///   included. A detail screen without its poster is still a detail screen, so this failing
    ///   costs a picture and nothing else: everything else still copies.
    func seriesPoster(for id: Int) async throws -> Data
}
