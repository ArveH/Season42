import Foundation
import Testing
@testable import Season42

/// Tests the other half of the movie search seam: what opening one of the matches does with
/// what the BFF answers. Opening a match lives on `MovieSearch` because it is the second half
/// of choosing which movie the user meant, so these run against the same stub the search tests
/// do.
///
/// Named for the search rather than for the screen, so that `MovieTests` — which is about
/// Tracked Movies in the Library — keeps the plainer name.
@MainActor
struct MovieDetailsSearchTests {
    // MARK: - Opening a match

    /// The screen is pushed by the tap that is itself the ask, so it has a title to show and a
    /// spinner to run before anything has arrived.
    @Test func openingAMatchRemembersWhichOneAndStartsLoading() async {
        let movies = StubMovies(details: arrival)
        movies.holdAnswers()
        let search = MovieSearch(text: "arriv", movies: movies)

        async let opening: Void = search.open(arrivalMatch)
        await movies.openStarted(329865)
        #expect(search.openedMatch == arrivalMatch)
        #expect(search.detailsState == .loading)

        movies.releaseOpen(329865)
        await opening
    }

    @Test func openingAMatchAsksForItsId() async {
        let movies = StubMovies(details: arrival)
        let search = MovieSearch(text: "arriv", movies: movies)

        await search.open(arrivalMatch)

        #expect(movies.opened == [329865])
    }

    @Test func anOpenedMatchShowsWhatItLoaded() async {
        let search = MovieSearch(text: "arriv", movies: StubMovies(details: arrival))

        await search.open(arrivalMatch)

        #expect(search.detailsState == .loaded(arrival))
    }

    /// The three fields the screen draws, and there is no fourth: a movie has no seasons.
    @Test func anOpenedMatchCarriesTheTitlesAndTheOverview() async {
        let search = MovieSearch(text: "arriv", movies: StubMovies(details: arrival))

        await search.open(arrivalMatch)

        #expect(search.details?.title == "Arrival")
        #expect(search.details?.originalTitle == "Arrival (original)")
        #expect(search.details?.overview.hasPrefix("An expert linguist") == true)
    }

    @Test func aMatchWhoseDetailsCouldNotBeReadFails() async {
        let search = MovieSearch(text: "arriv", movies: StubMovies(details: arrival, fails: true))

        await search.open(arrivalMatch)

        #expect(search.detailsState == .failed)
    }

    /// An id the BFF has no movie for is a failure like any other here: the user tapped a
    /// match the search served moments ago, and there is nothing for them to correct.
    @Test func aMatchTheBffHasNoMovieForFails() async {
        let search = MovieSearch(
            text: "arriv",
            movies: StubMovies(details: arrival, fails: true, as: .notServed(status: 404))
        )

        await search.open(arrivalMatch)

        #expect(search.detailsState == .failed)
    }

    // MARK: - What opening one leaves alone

    /// What Back returns to. The results are the search's, and reading a match's details is not
    /// a thing that touches them.
    @Test func openingAMatchLeavesTheResultsListed() async {
        let movies = StubMovies(matches: [arrivalMatch, duneMatch], details: arrival)
        let search = MovieSearch(text: "arriv", movies: movies)
        await search.search()

        await search.open(arrivalMatch)

        #expect(search.state == .results([arrivalMatch, duneMatch]))
    }

    /// Details that couldn't be read leave them listed too — that is the whole of what the
    /// failure tells the user to do about it.
    @Test func aFailedOpenLeavesTheResultsListed() async {
        let movies = StubMovies(matches: [arrivalMatch, duneMatch])
        let search = MovieSearch(text: "arriv", movies: movies)
        await search.search()

        movies.fails = true
        await search.open(arrivalMatch)

        #expect(search.detailsState == .failed)
        #expect(search.state == .results([arrivalMatch, duneMatch]))
    }

    /// Back and then a second match is the whole point of the Back button.
    @Test func openingASecondMatchReplacesTheFirstOnesDetails() async {
        let movies = StubMovies()
        movies.detailAnswers = [329865: arrival, 438631: dune]
        let search = MovieSearch(text: "e", movies: movies)
        await search.open(arrivalMatch)

        await search.open(duneMatch)

        #expect(search.openedMatch == duneMatch)
        #expect(search.details == dune)
    }

    /// A slow first open answering after a second match has already landed must not replace it:
    /// details under a title they didn't come from are worse than nothing.
    @Test func anOpenOvertakenByANewerOneNeverLands() async {
        let movies = StubMovies()
        movies.detailAnswers = [329865: arrival, 438631: dune]
        movies.holdAnswers()
        let search = MovieSearch(text: "e", movies: movies)

        async let overtaken: Void = search.open(arrivalMatch)
        await movies.openStarted(329865)
        async let newer: Void = search.open(duneMatch)
        await movies.openStarted(438631)

        movies.releaseOpen(438631)
        await newer
        #expect(search.details == dune)

        movies.releaseOpen(329865)
        await overtaken
        #expect(search.details == dune)
    }

    // MARK: - What the stub answers with

    private var arrivalMatch: MovieMatch { MovieMatch(id: 329865, title: "Arrival") }
    private var duneMatch: MovieMatch { MovieMatch(id: 438631, title: "Dune") }

    private var arrival: MovieDetails {
        MovieDetails(
            title: "Arrival",
            originalTitle: "Arrival (original)",
            overview: "An expert linguist is recruited by the military to determine whether the "
                + "visitors come in peace or are a threat.",
            hasPoster: false
        )
    }

    private var dune: MovieDetails {
        MovieDetails(
            title: "Dune",
            originalTitle: "Dune",
            overview: "Paul Atreides leads nomadic tribes in a revolt against the galactic emperor.",
            hasPoster: false
        )
    }
}
