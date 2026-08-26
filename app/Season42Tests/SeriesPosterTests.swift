import Foundation
import Testing
@testable import Season42

/// Tests the poster half of opening a match: that it is asked for only where the details say
/// there is one, that it is asked for once, that a poster which won't come costs a picture and
/// nothing else, and that what the screen drew is what a copy keeps.
@MainActor
struct SeriesPosterTests {
    // MARK: - Asking for it

    @Test func openingAMatchWithAPosterFetchesItByTheSameId() async {
        let series = StubSeries(details: withPoster, poster: bytes)
        let search = SeriesSearch(text: "sever", series: series)

        await search.open(severanceMatch)

        #expect(series.postersAsked == [95396])
        #expect(search.posterState == .adopted(bytes))
        #expect(search.poster == bytes)
    }

    /// A poster on its way is not a poster that isn't there: the details already said there is
    /// one, so the screen is told to wait rather than to draw the stand-in and take it back.
    @Test func aPosterOnItsWaySaysSoRatherThanReadingAsNone() async {
        let series = StubSeries(details: withPoster, poster: bytes)
        series.holdAnswers()
        let search = SeriesSearch(text: "sever", series: series)

        async let opening: Void = search.open(severanceMatch)
        await series.openStarted(95396)
        series.releaseOpen(95396)
        await series.posterStarted(95396)

        #expect(search.detailsState == .loaded(withPoster))
        #expect(search.posterState == .loading)
        #expect(search.poster == nil)

        series.releasePoster(95396)
        await opening
    }

    /// `hasPoster` is in the payload so the app can draw its placeholder without firing an ask
    /// it already knows will be refused.
    @Test func aSeriesTheDetailsSayHasNoPosterIsNeverAskedForOne() async {
        let series = StubSeries(details: withoutPoster, poster: bytes)
        let search = SeriesSearch(text: "sever", series: series)

        await search.open(severanceMatch)

        #expect(series.postersAsked.isEmpty)
        #expect(search.posterState == SeriesSearch.PosterState.none)
    }

    /// The bytes are fetched once, on the way to the screen that draws them, so Copy takes what
    /// the user actually looked at rather than asking again for something that may have moved.
    @Test func openingAMatchAsksForItsPosterOnlyOnce() async {
        let series = StubSeries(details: withPoster, poster: bytes)
        let search = SeriesSearch(text: "sever", series: series)

        await search.open(severanceMatch)

        #expect(series.postersAsked == [95396])
    }

    // MARK: - When it doesn't arrive

    /// A poster that won't fetch is no poster, not a failed screen: the details are read, the
    /// seasons are listed, and Copy still works. Exactly what a Watch Provider whose logo won't
    /// load already does.
    @Test func aPosterThatWillNotFetchLeavesTheDetailsStanding() async {
        let series = StubSeries(details: withPoster)
        series.posterFails = true
        let search = SeriesSearch(text: "sever", series: series)

        await search.open(severanceMatch)

        #expect(search.detailsState == .loaded(withPoster))
        #expect(search.posterState == SeriesSearch.PosterState.none)
    }

    @Test func detailsThatCouldNotBeReadAreNeverAskedForAPoster() async {
        let series = StubSeries(details: withPoster, poster: bytes, fails: true)
        let search = SeriesSearch(text: "sever", series: series)

        await search.open(severanceMatch)

        #expect(series.postersAsked.isEmpty)
        #expect(search.poster == nil)
    }

    // MARK: - Opening a second match

    /// A poster never outlives the series it was fetched for: the screen redraws under the new
    /// name the moment it is opened, and the old picture is not what it draws.
    @Test func openingASecondMatchClearsTheFirstPoster() async {
        let series = StubSeries()
        series.detailAnswers = [95396: withPoster, 1399: withoutPoster]
        series.posterAnswers = [95396: bytes]
        let search = SeriesSearch(text: "sever", series: series)

        await search.open(severanceMatch)
        await search.open(thronesMatch)

        #expect(search.poster == nil)
    }

    /// A poster owed to a match the user has left behind is dropped rather than drawn under the
    /// name of the one they went on to open — the same rule the details themselves follow.
    @Test func aPosterOwedToAnAbandonedMatchIsDropped() async {
        let series = StubSeries()
        series.detailAnswers = [95396: withPoster, 1399: withoutPoster]
        series.posterAnswers = [95396: bytes]
        series.holdAnswers()
        let search = SeriesSearch(text: "sever", series: series)

        async let first: Void = search.open(severanceMatch)
        await series.openStarted(95396)
        series.releaseOpen(95396)
        await series.posterStarted(95396)

        async let second: Void = search.open(thronesMatch)
        await series.openStarted(1399)
        series.releaseOpen(1399)

        series.releasePoster(95396)
        await first
        await second

        #expect(search.openedMatch == thronesMatch)
        #expect(search.poster == nil)
    }

    // MARK: - What a copy keeps

    @Test func aCopyKeepsThePosterTheScreenDrew() {
        let copy = withPoster.copy(over: .new, poster: bytes)

        #expect(copy.poster == bytes)
    }

    @Test func aCopyOfASeriesWithNoPosterKeepsNone() {
        let copy = withoutPoster.copy(over: .new, poster: nil)

        #expect(copy.poster == nil)
        #expect(copy.title == "Severance")
        #expect(copy.seasons == [9, 10])
    }

    // MARK: - What the stub answers with

    private var severanceMatch: SeriesMatch { SeriesMatch(id: 95396, name: "Severance") }
    private var thronesMatch: SeriesMatch { SeriesMatch(id: 1399, name: "Game of Thrones") }

    private var bytes: Data { Data("a poster".utf8) }

    private var withPoster: SeriesDetails { severance(hasPoster: true) }
    private var withoutPoster: SeriesDetails { severance(hasPoster: false) }

    private func severance(hasPoster: Bool) -> SeriesDetails {
        SeriesDetails(
            name: "Severance",
            originalName: "Severance",
            overview: "Mark leads a team of office workers whose memories have been surgically divided.",
            hasPoster: hasPoster,
            seasons: [
                SeriesSeason(seasonNumber: 0, episodeCount: 3),
                SeriesSeason(seasonNumber: 1, episodeCount: 9),
                SeriesSeason(seasonNumber: 2, episodeCount: 10),
            ]
        )
    }
}
