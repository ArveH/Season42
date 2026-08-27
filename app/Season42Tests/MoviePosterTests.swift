import Foundation
import Testing
@testable import Season42

/// Tests the poster half of opening a movie match: that it is asked for only where the details
/// say there is one, that it is asked for once, that a poster which won't come costs a picture
/// and nothing else, and that what the screen drew is what a copy keeps. The series' half of it
/// in `SeriesPosterTests`, on the same terms — a movie's Poster is adopted no differently.
@MainActor
struct MoviePosterTests {
    // MARK: - Asking for it

    @Test func openingAMatchWithAPosterFetchesItByTheSameId() async {
        let movies = StubMovies(details: withPoster, poster: bytes)
        let search = MovieSearch(text: "arriv", movies: movies)

        await search.open(arrivalMatch)

        #expect(movies.postersAsked == [329865])
        #expect(search.posterState == .adopted(bytes))
        #expect(search.poster == bytes)
    }

    /// A poster on its way is not a poster that isn't there: the details already said there is
    /// one, so the screen is told to wait rather than to draw the stand-in and take it back.
    @Test func aPosterOnItsWaySaysSoRatherThanReadingAsNone() async {
        let movies = StubMovies(details: withPoster, poster: bytes)
        movies.holdAnswers()
        let search = MovieSearch(text: "arriv", movies: movies)

        async let opening: Void = search.open(arrivalMatch)
        await movies.openStarted(329865)
        movies.releaseOpen(329865)
        await movies.posterStarted(329865)

        #expect(search.detailsState == .loaded(withPoster))
        #expect(search.posterState == .loading)
        #expect(search.poster == nil)

        movies.releasePoster(329865)
        await opening
    }

    /// `hasPoster` is in the payload so the app can draw its placeholder without firing an ask
    /// it already knows will be refused.
    @Test func aMovieTheDetailsSayHasNoPosterIsNeverAskedForOne() async {
        let movies = StubMovies(details: withoutPoster, poster: bytes)
        let search = MovieSearch(text: "arriv", movies: movies)

        await search.open(arrivalMatch)

        #expect(movies.postersAsked.isEmpty)
        #expect(search.posterState == MovieSearch.PosterState.none)
    }

    /// The bytes are fetched once, on the way to the screen that draws them, so Copy takes what
    /// the user actually looked at rather than asking again for something that may have moved.
    @Test func openingAMatchAsksForItsPosterOnlyOnce() async {
        let movies = StubMovies(details: withPoster, poster: bytes)
        let search = MovieSearch(text: "arriv", movies: movies)

        await search.open(arrivalMatch)

        #expect(movies.postersAsked == [329865])
    }

    // MARK: - When it doesn't arrive

    /// A poster that won't fetch is no poster, not a failed screen: the details are read and
    /// Copy still works. Exactly what a Watch Provider whose logo won't load already does.
    @Test func aPosterThatWillNotFetchLeavesTheDetailsStanding() async {
        let movies = StubMovies(details: withPoster)
        movies.posterFails = true
        let search = MovieSearch(text: "arriv", movies: movies)

        await search.open(arrivalMatch)

        #expect(search.detailsState == .loaded(withPoster))
        #expect(search.posterState == MovieSearch.PosterState.none)
    }

    @Test func detailsThatCouldNotBeReadAreNeverAskedForAPoster() async {
        let movies = StubMovies(details: withPoster, poster: bytes, fails: true)
        let search = MovieSearch(text: "arriv", movies: movies)

        await search.open(arrivalMatch)

        #expect(movies.postersAsked.isEmpty)
        #expect(search.poster == nil)
    }

    // MARK: - Opening a second match

    /// A poster never outlives the movie it was fetched for: the screen redraws under the new
    /// title the moment it is opened, and the old picture is not what it draws.
    @Test func openingASecondMatchClearsTheFirstPoster() async {
        let movies = StubMovies()
        movies.detailAnswers = [329865: withPoster, 438631: withoutPoster]
        movies.posterAnswers = [329865: bytes]
        let search = MovieSearch(text: "arriv", movies: movies)

        await search.open(arrivalMatch)
        await search.open(duneMatch)

        #expect(search.poster == nil)
    }

    /// A poster owed to a match the user has left behind is dropped rather than drawn under the
    /// title of the one they went on to open — the same rule the details themselves follow.
    @Test func aPosterOwedToAnAbandonedMatchIsDropped() async {
        let movies = StubMovies()
        movies.detailAnswers = [329865: withPoster, 438631: withoutPoster]
        movies.posterAnswers = [329865: bytes]
        movies.holdAnswers()
        let search = MovieSearch(text: "arriv", movies: movies)

        async let first: Void = search.open(arrivalMatch)
        await movies.openStarted(329865)
        movies.releaseOpen(329865)
        await movies.posterStarted(329865)

        async let second: Void = search.open(duneMatch)
        await movies.openStarted(438631)
        movies.releaseOpen(438631)

        movies.releasePoster(329865)
        await first
        await second

        #expect(search.openedMatch == duneMatch)
        #expect(search.poster == nil)
    }

    // MARK: - What a copy keeps

    @Test func aCopyKeepsThePosterTheScreenDrew() {
        let copy = withPoster.copy(over: .new, poster: bytes)

        #expect(copy.poster == bytes)
    }

    @Test func aCopyOfAMovieWithNoPosterKeepsNone() {
        let copy = withoutPoster.copy(over: .new, poster: nil)

        #expect(copy.poster == nil)
        #expect(copy.title == "Arrival")
    }

    // MARK: - What the stub answers with

    private var arrivalMatch: MovieMatch { MovieMatch(id: 329865, title: "Arrival") }
    private var duneMatch: MovieMatch { MovieMatch(id: 438631, title: "Dune") }

    private var bytes: Data { Data("a poster".utf8) }

    private var withPoster: MovieDetails { arrival(hasPoster: true) }
    private var withoutPoster: MovieDetails { arrival(hasPoster: false) }

    private func arrival(hasPoster: Bool) -> MovieDetails {
        MovieDetails(
            title: "Arrival",
            originalTitle: "Arrival",
            overview: "An expert linguist is recruited to work out whether the visitors come in peace.",
            hasPoster: hasPoster
        )
    }
}
