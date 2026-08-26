import Foundation

/// A search for a series, and everything the search sheet is holding while it runs: the text
/// being searched for, where the search has got to, and — once the user has opened one of the
/// matches — where reading its Series Details has got to. Every decision about a search lives
/// here — that a blank text searches for nothing, that an empty answer is not a failure, that
/// a stale answer is dropped — so the sheet renders this and decides nothing, and all of it is
/// tested against a stub.
///
/// Opening a match is part of the search rather than a thing of its own: it is the second half
/// of choosing which series the user meant, and it is what a Series Match's id exists to be
/// asked with.
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

    /// Where reading the details of the opened match has got to. There is no "nothing yet":
    /// nothing reads this until a match has been opened, and opening one is itself the ask.
    enum DetailsState: Equatable {
        /// The details are on their way. What the detail screen spins on.
        case loading

        /// What the BFF answered with.
        case loaded(SeriesDetails)

        /// The details couldn't be read at all — the BFF is unreachable, has no series under
        /// that id, or answered with something that isn't a Series Details. All one thing to
        /// the user: they opened a match the search served moments ago, and there is nothing
        /// here for them to correct. Back still lists what the search matched.
        case failed
    }

    /// What the search is for. Pre-filled from the Title the sheet was opened over, and the
    /// user's to correct from there without the Title moving with it.
    var text: String

    private(set) var state: State = .idle

    /// The match whose details are being read, and nil until one has been opened. What the
    /// detail screen puts in its title bar, so the user sees which of several similar titles
    /// they tapped before anything has arrived.
    private(set) var openedMatch: SeriesMatch?

    private(set) var detailsState: DetailsState = .loading

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

    /// Opens `match` and reads its details. The results are left exactly as they are, which is
    /// what makes Back a return to them rather than a second search.
    ///
    /// Never throws: details that can't be read are a state the detail screen shows. A match
    /// opened while an earlier one's details are still owed makes the earlier answer stale, and
    /// a stale answer is dropped rather than shown under the wrong name.
    func open(_ match: SeriesMatch) async {
        openedMatch = match
        detailsState = .loading
        do {
            let details = try await series.details(for: match.id)
            guard openedMatch == match else { return }
            detailsState = .loaded(details)
        } catch {
            guard openedMatch == match else { return }
            detailsState = .failed
        }
    }
}
