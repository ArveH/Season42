import Foundation

/// A search for a movie, and everything the search sheet is holding while it runs: the text
/// being searched for, where the search has got to, and — once the user has opened one of the
/// matches — where reading its Movie Details has got to. Every decision about a search lives
/// here — that a blank text searches for nothing, that an empty answer is not a failure, that
/// a stale answer is dropped — so the sheet renders this and decides nothing, and all of it is
/// tested against a stub.
///
/// Opening a match is part of the search rather than a thing of its own: it is the second half
/// of choosing which movie the user meant, and it is what a Movie Match's id exists to be asked
/// with.
///
/// The same shape as `SeriesSearch`, poster and all: a movie's Poster is adopted on the same
/// terms as a series', so opening a match reads the details and then fetches the picture the
/// screen draws and Copy keeps.
///
/// The text starts out as the form's Title and is not the form's Title: it is a copy, editable
/// here and written back nowhere. Only copying a match ever reaches the form.
@MainActor
@Observable
final class MovieSearch {
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
        case results([MovieMatch])

        /// The search ran and nothing matched the text.
        case matchedNothing

        /// The search couldn't be run at all — the BFF is unreachable, or answered with
        /// something that isn't a list of Movie Matches.
        case failed
    }

    /// Where reading the details of the opened match has got to. There is no "nothing yet":
    /// nothing reads this until a match has been opened, and opening one is itself the ask.
    enum DetailsState: Equatable {
        /// The details are on their way. What the detail screen spins on.
        case loading

        /// What the BFF answered with.
        case loaded(MovieDetails)

        /// The details couldn't be read at all — the BFF is unreachable, has no movie under
        /// that id, or answered with something that isn't a Movie Details. All one thing to
        /// the user: they opened a match the search served moments ago, and there is nothing
        /// here for them to correct. Back still lists what the search matched.
        case failed
    }

    /// Where the opened match's poster has got to. Three cases and not an optional, because
    /// "there is none" and "it hasn't arrived yet" are different things to draw: a stand-in
    /// for the first would be a lie for the second, and the details already say which it is.
    enum PosterState: Equatable {
        /// There is no poster to draw — TMDB has none, or the bytes would not come. One case
        /// for both: to the user they are the same missing picture, and there is nothing to
        /// correct either way.
        case none

        /// TMDB has one and it is on its way.
        case loading

        /// The bytes, which are what the detail screen draws and what Copy keeps.
        case adopted(Data)
    }

    /// What the search is for. Pre-filled from the Title the sheet was opened over, and the
    /// user's to correct from there without the Title moving with it.
    var text: String

    private(set) var state: State = .idle

    /// The match whose details are being read, and nil until one has been opened. What the
    /// detail screen puts in its title bar, so the user sees which of several similar titles
    /// they tapped before anything has arrived.
    private(set) var openedMatch: MovieMatch?

    private(set) var detailsState: DetailsState = .loading

    /// Where the opened match's poster has got to. Fetched once, here: what the detail screen
    /// draws is what Copy keeps, so there is one ask and not two.
    ///
    /// Reset the moment another match is opened, so a poster never outlives the movie it was
    /// fetched for.
    private(set) var posterState: PosterState = .none

    /// The bytes to draw and to copy, and nil where there are none — which a poster still on
    /// its way is too: nothing keeps what hasn't arrived.
    var poster: Data? {
        guard case .adopted(let bytes) = posterState else { return nil }
        return bytes
    }

    private let movies: any MovieSearching

    /// Which search is the current one. A second search started before the first has answered
    /// makes the first one's answer stale, and a stale answer is dropped rather than shown:
    /// results under a text they did not come from are worse than the spinner they would
    /// replace.
    private var currentSearch = 0

    /// - Parameter text: what the search box starts out holding — the form's Title, which is
    ///   nothing at all on a form nothing has been typed into yet.
    init(text: String, movies: any MovieSearching) {
        self.text = text
        self.movies = movies
    }

    /// Searches for what is in the box. A blank box does nothing at all rather than erroring
    /// — there is no mistake in not having typed yet — and leaves whatever the last search
    /// left on screen.
    ///
    /// Never throws: a search that can't be run is a state the sheet shows inline. The form
    /// underneath stays exactly as the user left it, because entering a movie by hand is
    /// what the search was only ever a shortcut around.
    func search() async {
        let wanted = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wanted.isEmpty else { return }

        currentSearch += 1
        let thisSearch = currentSearch
        state = .searching
        do {
            let matched = try await movies.movies(matching: wanted)
            guard thisSearch == currentSearch else { return }
            state = matched.isEmpty ? .matchedNothing : .results(matched)
        } catch {
            guard thisSearch == currentSearch else { return }
            state = .failed
        }
    }

    /// Opens `match`, reads its details, and fetches the poster if the details say there is
    /// one. The results are left exactly as they are, which is what makes Back a return to them
    /// rather than a second search.
    ///
    /// Never throws: details that can't be read are a state the detail screen shows, and a
    /// poster that can't be fetched is simply no poster — it costs a picture and stops nothing.
    /// A match opened while an earlier one's answers are still owed makes them stale, and a
    /// stale answer is dropped rather than shown under the wrong title.
    func open(_ match: MovieMatch) async {
        openedMatch = match
        detailsState = .loading
        posterState = .none
        do {
            let details = try await movies.movieDetails(for: match.id)
            guard openedMatch == match else { return }
            detailsState = .loaded(details)

            // Nothing to ask for where TMDB has no poster, which is what `hasPoster` is in the
            // payload for: a placeholder is drawn without an ask that would only be refused.
            guard details.hasPoster else { return }
            posterState = .loading
            let bytes = try? await movies.moviePoster(for: match.id)
            guard openedMatch == match else { return }
            posterState = bytes.map(PosterState.adopted) ?? .none
        } catch {
            guard openedMatch == match else { return }
            detailsState = .failed
        }
    }
}
