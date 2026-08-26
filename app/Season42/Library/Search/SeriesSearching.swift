import Foundation

/// Where a search for a series gets its answers from. Two asks and no rules: which text to
/// search for, what an empty answer means and what a fetch that failed shows are all decisions
/// of `SeriesSearch` and `SeriesDetailsRequest` — which is what lets every one of them be
/// tested against a stub and leaves only `BffClient` needing a network.
///
/// Two asks and not one, because opening a match is the second half of searching: the search
/// answers with ids, and an id is only good for asking the next question with. Separate from
/// `LogoSearching` rather than folded in with it, so that the logo stub beside it is untouched
/// by anything that happens here.
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
    /// - Throws: whatever went wrong reaching or reading the answer, an id the BFF has no
    ///   series for included. Unlike a search, there is no empty answer to tell apart from a
    ///   failure: the user tapped a match that was served moments ago, so anything other than
    ///   the details is the same "couldn't ask" to them.
    func details(for id: Int) async throws -> SeriesDetails
}
