import Foundation

/// A search for a series, and everything the search sheet is holding while it runs: the text
/// being searched for and where the search has got to. Every decision about a search lives
/// here — that a blank text searches for nothing, that an empty answer is not a failure, that
/// a stale answer is dropped — so the sheet renders this and decides nothing, and all of it is
/// tested against a stub.
///
/// The text starts out as the form's Title and is not the form's Title: it is a copy, editable
/// here and written back nowhere. Only copying a match, which this cannot yet do, will ever
/// reach the form.
@MainActor
@Observable
final class SeriesSearch {
    /// Where a search has got to. The two ways of coming back with nothing to show are
    /// separate cases because they call for different actions: one is "try another spelling",
    /// the other is "the server isn't there, enter it by hand".
    enum State: Equatable {
        /// Nothing has been searched for yet — which is what a sheet opened from an empty
        /// Title shows: an empty box, ready to type in.
        case idle

        /// A search is in flight. What the sheet spins on.
        case searching

        /// What the search matched, in the order the BFF served them.
        case results([SeriesMatch])

        /// The search ran and nothing matched the text.
        case matchedNothing

        /// The search couldn't be run at all — the BFF is unreachable, or answered with
        /// something that isn't a list of Series Matches.
        case failed
    }

    /// What the search is for. Pre-filled from the Title the sheet was opened over, and the
    /// user's to correct from there without the Title moving with it.
    var text: String

    private(set) var state: State = .idle

    private let series: any SeriesSearching

    /// Which search is the current one. A second search started before the first has answered
    /// makes the first one's answer stale, and a stale answer is dropped rather than shown:
    /// results under a text they did not come from are worse than the spinner they would
    /// replace.
    private var currentSearch = 0

    /// - Parameter text: what the search box starts out holding — the form's Title, which is
    ///   nothing at all on a form nothing has been typed into yet.
    init(text: String, series: any SeriesSearching) {
        self.text = text
        self.series = series
    }

    /// Searches for what is in the box. A blank box does nothing at all rather than erroring
    /// — there is no mistake in not having typed yet — and leaves whatever the last search
    /// left on screen.
    ///
    /// Never throws: a search that can't be run is a state the sheet shows inline. The form
    /// underneath stays exactly as the user left it, because entering a series by hand is
    /// what the search was only ever a shortcut around.
    func search() async {
        let wanted = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wanted.isEmpty else { return }

        currentSearch += 1
        let thisSearch = currentSearch
        state = .searching
        do {
            let matched = try await series.series(matching: wanted)
            guard thisSearch == currentSearch else { return }
            state = matched.isEmpty ? .matchedNothing : .results(matched)
        } catch {
            guard thisSearch == currentSearch else { return }
            state = .failed
        }
    }
}
