import Foundation
import Testing
@testable import Season42

/// Tests the search seam: what a search for a series does with what the BFF answers. What
/// opening one of its matches does is `SeriesDetailsTests`, on the same type and the same stub.
/// Everything here runs against `StubSeries` — only `BffClient` needs a network, and it holds
/// no rules for a test to check.
@MainActor
struct SeriesSearchTests {
    // MARK: - Where a search starts from

    /// The sheet is opened from the form's Title, so the box arrives holding it.
    @Test func aSearchStartsFromTheTitleItWasOpenedWith() {
        let search = SeriesSearch(text: "Severance", series: StubSeries())

        #expect(search.text == "Severance")
        #expect(search.state == .idle)
    }

    @Test func aSearchOpenedFromAnEmptyTitleStartsEmpty() {
        let search = SeriesSearch(text: "", series: StubSeries())

        #expect(search.text.isEmpty)
        #expect(search.state == .idle)
    }

    // MARK: - Running a search

    @Test func aSearchShowsWhatItMatched() async {
        let search = SeriesSearch(text: "sever", series: StubSeries(matches: [severance]))

        await search.search()

        #expect(search.state == .results([severance]))
    }

    @Test func aSearchSearchesForWhatIsInTheBox() async {
        let series = StubSeries(matches: [severance])
        let search = SeriesSearch(text: "  sever  ", series: series)

        await search.search()

        #expect(series.searched == ["sever"])
    }

    @Test func aBlankSearchSearchesForNothing() async {
        let series = StubSeries(matches: [severance])
        let search = SeriesSearch(text: "   ", series: series)

        await search.search()

        #expect(series.searched.isEmpty)
        #expect(search.state == .idle)
    }

    /// The state a spinner is keyed off, seen while the answer is still owed.
    @Test func aSearchInFlightSaysSo() async {
        let series = StubSeries(matches: [severance])
        series.holdAnswers()
        let search = SeriesSearch(text: "sever", series: series)

        async let ran: Void = search.search()
        await series.searchStarted("sever")
        #expect(search.state == .searching)

        series.releaseSearch("sever")
        await ran
        #expect(search.state != .searching)
    }

    /// A slow first search answering after a second one has already landed must not replace
    /// it: results under a text they didn't come from are worse than nothing.
    @Test func aSearchOvertakenByANewerOneNeverLands() async {
        let series = StubSeries()
        series.answers = ["sever": [severance], "thrones": [thrones]]
        series.holdAnswers()
        let search = SeriesSearch(text: "sever", series: series)

        async let overtaken: Void = search.search()
        await series.searchStarted("sever")
        search.text = "thrones"
        async let newer: Void = search.search()
        await series.searchStarted("thrones")

        series.releaseSearch("thrones")
        await newer
        #expect(search.results.map(\.name) == ["Game of Thrones"])

        series.releaseSearch("sever")
        await overtaken
        #expect(search.results.map(\.name) == ["Game of Thrones"])
    }

    @Test func aSearchThatMatchedNothingIsNotAFailure() async {
        let search = SeriesSearch(text: "zzz", series: StubSeries(matches: []))

        await search.search()

        #expect(search.state == .matchedNothing)
    }

    @Test func aSearchThatCouldNotBeRunFails() async {
        let search = SeriesSearch(text: "sever", series: StubSeries(fails: true))

        await search.search()

        #expect(search.state == .failed)
    }

    /// The results are the BFF's order — TMDB's own relevance — not the app's.
    @Test func resultsKeepTheOrderTheyWereServedIn() async {
        let search = SeriesSearch(text: "e", series: StubSeries(matches: [severance, thrones, theBear]))

        await search.search()

        #expect(search.results.map(\.name) == ["Severance", "Game of Thrones", "The Bear"])
    }

    /// The BFF answers about TMDB. What the user is already tracking is `Library`'s business,
    /// and nothing here consults it.
    @Test func resultsAreNotFilteredAgainstAnythingTheAppKnows() async {
        let search = SeriesSearch(text: "sever", series: StubSeries(matches: [severance]))

        await search.search()

        #expect(search.results == [severance])
    }

    @Test func aSecondSearchReplacesTheFirstOnesResults() async {
        let series = StubSeries(matches: [severance])
        let search = SeriesSearch(text: "sever", series: series)
        await search.search()

        series.served = []
        search.text = "zzz"
        await search.search()

        #expect(search.state == .matchedNothing)
    }

    /// Correcting the text in the box is what the box is for, and it reaches nothing else.
    @Test func aSearchThatFailedCanBeRunAgain() async {
        let series = StubSeries(matches: [severance], fails: true)
        let search = SeriesSearch(text: "sever", series: series)
        await search.search()

        series.fails = false
        await search.search()

        #expect(search.results == [severance])
    }

    // MARK: - What the stub answers with

    private var severance: SeriesMatch { SeriesMatch(id: 95396, name: "Severance") }
    private var thrones: SeriesMatch { SeriesMatch(id: 1399, name: "Game of Thrones") }
    private var theBear: SeriesMatch { SeriesMatch(id: 136315, name: "The Bear") }
}

private extension SeriesSearch {
    /// The matches on screen, for the tests that are about what a search produced rather than
    /// which state it is in.
    var results: [SeriesMatch] {
        guard case .results(let matches) = state else { return [] }
        return matches
    }
}
