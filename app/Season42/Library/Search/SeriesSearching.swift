import Foundation

/// Where a search for a series gets its answers from. One ask and no rules: which text to
/// search for and what an empty answer means are both `SeriesSearch`'s decisions — which is
/// what lets every one of them be tested against a stub and leaves only `BffClient` needing a
/// network.
///
/// Narrow on purpose, and separate from `LogoSearching` rather than folded in with it: a stub
/// standing in for this implements one method, and the logo stub beside it is untouched by
/// anything that happens here.
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
}
