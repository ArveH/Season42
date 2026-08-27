import Foundation
import Testing
@testable import Season42

/// Tests the movie search seam: what a search for a movie does with what the BFF answers. What
/// opening one of its matches does is `MovieDetailsSearchTests`, on the same type and the same
/// stub. Everything here runs against `StubMovies` — only `BffClient` needs a network, and it
/// holds no rules for a test to check.
@MainActor
struct MovieSearchTests {
    // MARK: - Where a search starts from

    /// The sheet is opened from the form's Title, so the box arrives holding it.
    @Test func aSearchStartsFromTheTitleItWasOpenedWith() {
        let search = MovieSearch(text: "Arrival", movies: StubMovies())

        #expect(search.text == "Arrival")
        #expect(search.state == .idle)
    }

    @Test func aSearchOpenedFromAnEmptyTitleStartsEmpty() {
        let search = MovieSearch(text: "", movies: StubMovies())

        #expect(search.text.isEmpty)
        #expect(search.state == .idle)
    }

    // MARK: - Running a search

    @Test func aSearchShowsWhatItMatched() async {
        let search = MovieSearch(text: "arriv", movies: StubMovies(matches: [arrival]))

        await search.search()

        #expect(search.state == .results([arrival]))
    }

    @Test func aSearchSearchesForWhatIsInTheBox() async {
        let movies = StubMovies(matches: [arrival])
        let search = MovieSearch(text: "  arriv  ", movies: movies)

        await search.search()

        #expect(movies.searched == ["arriv"])
    }

    @Test func aBlankSearchSearchesForNothing() async {
        let movies = StubMovies(matches: [arrival])
        let search = MovieSearch(text: "   ", movies: movies)

        await search.search()

        #expect(movies.searched.isEmpty)
        #expect(search.state == .idle)
    }

    /// The state a spinner is keyed off, seen while the answer is still owed.
    @Test func aSearchInFlightSaysSo() async {
        let movies = StubMovies(matches: [arrival])
        movies.holdAnswers()
        let search = MovieSearch(text: "arriv", movies: movies)

        async let ran: Void = search.search()
        await movies.searchStarted("arriv")
        #expect(search.state == .searching)

        movies.releaseSearch("arriv")
        await ran
        #expect(search.state != .searching)
    }

    /// A slow first search answering after a second one has already landed must not replace
    /// it: results under a text they didn't come from are worse than nothing.
    @Test func aSearchOvertakenByANewerOneNeverLands() async {
        let movies = StubMovies()
        movies.answers = ["arriv": [arrival], "dune": [dune]]
        movies.holdAnswers()
        let search = MovieSearch(text: "arriv", movies: movies)

        async let overtaken: Void = search.search()
        await movies.searchStarted("arriv")
        search.text = "dune"
        async let newer: Void = search.search()
        await movies.searchStarted("dune")

        movies.releaseSearch("dune")
        await newer
        #expect(search.results.map(\.title) == ["Dune"])

        movies.releaseSearch("arriv")
        await overtaken
        #expect(search.results.map(\.title) == ["Dune"])
    }

    @Test func aSearchThatMatchedNothingIsNotAFailure() async {
        let search = MovieSearch(text: "zzz", movies: StubMovies(matches: []))

        await search.search()

        #expect(search.state == .matchedNothing)
    }

    @Test func aSearchThatCouldNotBeRunFails() async {
        let search = MovieSearch(text: "arriv", movies: StubMovies(fails: true))

        await search.search()

        #expect(search.state == .failed)
    }

    /// The results are the BFF's order — TMDB's own relevance — not the app's.
    @Test func resultsKeepTheOrderTheyWereServedIn() async {
        let search = MovieSearch(text: "e", movies: StubMovies(matches: [arrival, dune, heat]))

        await search.search()

        #expect(search.results.map(\.title) == ["Arrival", "Dune", "Heat"])
    }

    /// The BFF answers about TMDB. What the user is already tracking is `Library`'s business,
    /// and nothing here consults it.
    @Test func resultsAreNotFilteredAgainstAnythingTheAppKnows() async {
        let search = MovieSearch(text: "arriv", movies: StubMovies(matches: [arrival]))

        await search.search()

        #expect(search.results == [arrival])
    }

    @Test func aSecondSearchReplacesTheFirstOnesResults() async {
        let movies = StubMovies(matches: [arrival])
        let search = MovieSearch(text: "arriv", movies: movies)
        await search.search()

        movies.served = []
        search.text = "zzz"
        await search.search()

        #expect(search.state == .matchedNothing)
    }

    /// Correcting the text in the box is what the box is for, and it reaches nothing else.
    @Test func aSearchThatFailedCanBeRunAgain() async {
        let movies = StubMovies(matches: [arrival], fails: true)
        let search = MovieSearch(text: "arriv", movies: movies)
        await search.search()

        movies.fails = false
        await search.search()

        #expect(search.results == [arrival])
    }

    // MARK: - What the stub answers with

    private var arrival: MovieMatch { MovieMatch(id: 329865, title: "Arrival") }
    private var dune: MovieMatch { MovieMatch(id: 438631, title: "Dune") }
    private var heat: MovieMatch { MovieMatch(id: 949, title: "Heat") }
}

extension MovieSearch {
    /// The matches on screen, for the tests that are about what a search produced rather than
    /// which state it is in.
    var results: [MovieMatch] {
        guard case .results(let matches) = state else { return [] }
        return matches
    }

    /// What is on the detail screen, for the tests that are about what an open produced rather
    /// than which state it is in.
    var details: MovieDetails? {
        guard case .loaded(let details) = detailsState else { return nil }
        return details
    }
}
