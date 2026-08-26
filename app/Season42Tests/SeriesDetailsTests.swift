import Foundation
import Testing
@testable import Season42

/// Tests the other half of the search seam: what opening one of the matches does with what the
/// BFF answers. Opening a match lives on `SeriesSearch` because it is the second half of
/// choosing which series the user meant, so these run against the same stub the search tests do.
@MainActor
struct SeriesDetailsTests {
    // MARK: - Opening a match

    /// The screen is pushed by the tap that is itself the ask, so it has a name to show and a
    /// spinner to run before anything has arrived.
    @Test func openingAMatchRemembersWhichOneAndStartsLoading() async {
        let series = StubSeries(details: severance)
        series.holdAnswers()
        let search = SeriesSearch(text: "sever", series: series)

        async let opening: Void = search.open(severanceMatch)
        await series.openStarted(95396)
        #expect(search.openedMatch == severanceMatch)
        #expect(search.detailsState == .loading)

        series.releaseOpen(95396)
        await opening
    }

    @Test func openingAMatchAsksForItsId() async {
        let series = StubSeries(details: severance)
        let search = SeriesSearch(text: "sever", series: series)

        await search.open(severanceMatch)

        #expect(series.opened == [95396])
    }

    @Test func anOpenedMatchShowsWhatItLoaded() async {
        let search = SeriesSearch(text: "sever", series: StubSeries(details: severance))

        await search.open(severanceMatch)

        #expect(search.detailsState == .loaded(severance))
    }

    /// The BFF passes season 0 through, and so does this: what the app makes of the specials is
    /// a matter for what draws them, not for what asked.
    @Test func anOpenedMatchKeepsEverySeasonTheBffAnsweredWith() async {
        let search = SeriesSearch(text: "sever", series: StubSeries(details: severance))

        await search.open(severanceMatch)

        #expect(search.details?.seasons.map(\.seasonNumber) == [0, 1, 2])
        #expect(search.details?.seasons.map(\.episodeCount) == [3, 9, 10])
    }

    @Test func aMatchWhoseDetailsCouldNotBeReadFails() async {
        let search = SeriesSearch(text: "sever", series: StubSeries(details: severance, fails: true))

        await search.open(severanceMatch)

        #expect(search.detailsState == .failed)
    }

    /// An id the BFF has no series for is a failure like any other here: the user tapped a
    /// match the search served moments ago, and there is nothing for them to correct.
    @Test func aMatchTheBffHasNoSeriesForFails() async {
        let search = SeriesSearch(
            text: "sever",
            series: StubSeries(details: severance, fails: true, as: .notServed(status: 404))
        )

        await search.open(severanceMatch)

        #expect(search.detailsState == .failed)
    }

    // MARK: - What opening one leaves alone

    /// What Back returns to. The results are the search's, and reading a match's details is not
    /// a thing that touches them.
    @Test func openingAMatchLeavesTheResultsListed() async {
        let series = StubSeries(matches: [severanceMatch, thronesMatch], details: severance)
        let search = SeriesSearch(text: "sever", series: series)
        await search.search()

        await search.open(severanceMatch)

        #expect(search.state == .results([severanceMatch, thronesMatch]))
    }

    /// Details that couldn't be read leave them listed too — that is the whole of what the
    /// failure tells the user to do about it.
    @Test func aFailedOpenLeavesTheResultsListed() async {
        let series = StubSeries(matches: [severanceMatch, thronesMatch])
        let search = SeriesSearch(text: "sever", series: series)
        await search.search()

        series.fails = true
        await search.open(severanceMatch)

        #expect(search.detailsState == .failed)
        #expect(search.state == .results([severanceMatch, thronesMatch]))
    }

    /// Back and then a second match is the whole point of the Back button.
    @Test func openingASecondMatchReplacesTheFirstOnesDetails() async {
        let series = StubSeries()
        series.detailAnswers = [95396: severance, 1399: thrones]
        let search = SeriesSearch(text: "e", series: series)
        await search.open(severanceMatch)

        await search.open(thronesMatch)

        #expect(search.openedMatch == thronesMatch)
        #expect(search.details == thrones)
    }

    /// A slow first open answering after a second match has already landed must not replace it:
    /// details under a name they didn't come from are worse than nothing.
    @Test func anOpenOvertakenByANewerOneNeverLands() async {
        let series = StubSeries()
        series.detailAnswers = [95396: severance, 1399: thrones]
        series.holdAnswers()
        let search = SeriesSearch(text: "e", series: series)

        async let overtaken: Void = search.open(severanceMatch)
        await series.openStarted(95396)
        async let newer: Void = search.open(thronesMatch)
        await series.openStarted(1399)

        series.releaseOpen(1399)
        await newer
        #expect(search.details == thrones)

        series.releaseOpen(95396)
        await overtaken
        #expect(search.details == thrones)
    }

    // MARK: - What the stub answers with

    private var severanceMatch: SeriesMatch { SeriesMatch(id: 95396, name: "Severance") }
    private var thronesMatch: SeriesMatch { SeriesMatch(id: 1399, name: "Game of Thrones") }

    private var severance: SeriesDetails {
        SeriesDetails(
            name: "Severance",
            originalName: "Severance",
            overview: "Mark leads a team of office workers whose memories have been surgically divided.",
            seasons: [
                SeriesSeason(seasonNumber: 0, episodeCount: 3),
                SeriesSeason(seasonNumber: 1, episodeCount: 9),
                SeriesSeason(seasonNumber: 2, episodeCount: 10),
            ]
        )
    }

    private var thrones: SeriesDetails {
        SeriesDetails(
            name: "Game of Thrones",
            originalName: "Game of Thrones",
            overview: "Seven noble families fight for control of the mythical land of Westeros.",
            seasons: [SeriesSeason(seasonNumber: 1, episodeCount: 10)]
        )
    }
}

private extension SeriesSearch {
    /// What is on the detail screen, for the tests that are about what an open produced rather
    /// than which state it is in.
    var details: SeriesDetails? {
        guard case .loaded(let details) = detailsState else { return nil }
        return details
    }
}
