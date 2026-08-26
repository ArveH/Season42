import Foundation
import Testing
@testable import Season42

/// Tests the details seam: what opening one Series Match does with what the BFF answers.
/// Everything here runs against a stub — only `BffClient` needs a network, and it holds no
/// rules for a test to check.
@MainActor
struct SeriesDetailsTests {
    // MARK: - Where a request starts from

    /// The screen is pushed from a match, so it has a name to show before anything has
    /// arrived — the user tapped it and knows which one they tapped.
    @Test func aRequestStartsFromTheMatchItWasOpenedWith() {
        let request = SeriesDetailsRequest(for: severanceMatch, series: StubDetails())

        #expect(request.match == severanceMatch)
        #expect(request.state == .loading)
    }

    // MARK: - Running a request

    @Test func aRequestAsksForTheIdOfTheMatchItWasOpenedWith() async {
        let series = StubDetails(details: severance)
        let request = SeriesDetailsRequest(for: severanceMatch, series: series)

        await request.load()

        #expect(series.asked == [95396])
    }

    @Test func aRequestShowsWhatItLoaded() async {
        let request = SeriesDetailsRequest(for: severanceMatch, series: StubDetails(details: severance))

        await request.load()

        #expect(request.state == .loaded(severance))
    }

    /// The BFF passes season 0 through, and so does this: what the app makes of the specials
    /// is a matter for what draws them, not for what asked.
    @Test func aRequestKeepsEverySeasonTheBffAnswersWith() async {
        let request = SeriesDetailsRequest(for: severanceMatch, series: StubDetails(details: severance))

        await request.load()

        #expect(request.details?.seasons.map(\.seasonNumber) == [0, 1, 2])
        #expect(request.details?.seasons.map(\.episodeCount) == [3, 9, 10])
    }

    @Test func aRequestThatCouldNotBeRunFails() async {
        let request = SeriesDetailsRequest(for: severanceMatch, series: StubDetails(fails: true))

        await request.load()

        #expect(request.state == .failed)
    }

    /// An id the BFF has no series for is a failure like any other here: the user tapped a
    /// match the search served moments ago, and there is nothing for them to correct.
    @Test func aRequestForSomethingTheBffHasNoSeriesForFails() async {
        let request = SeriesDetailsRequest(
            for: severanceMatch, series: StubDetails(fails: true, as: .notServed(status: 404)))

        await request.load()

        #expect(request.state == .failed)
    }

    /// What the Retry button does. Nothing about the match changed, so it is the same ask.
    @Test func aRequestThatFailedCanBeRunAgain() async {
        let series = StubDetails(details: severance, fails: true)
        let request = SeriesDetailsRequest(for: severanceMatch, series: series)
        await request.load()

        series.fails = false
        await request.load()

        #expect(request.state == .loaded(severance))
        #expect(series.asked == [95396, 95396])
    }

    /// The state a spinner is keyed off, seen while the answer is still owed.
    @Test func aRequestInFlightSaysSo() async {
        let series = StubDetails(details: severance)
        series.holdRequests()
        let request = SeriesDetailsRequest(for: severanceMatch, series: series)

        async let ran: Void = request.load()
        await series.requestStarted(95396)
        #expect(request.state == .loading)

        series.release(95396)
        await ran
        #expect(request.state == .loaded(severance))
    }

    /// Retrying after a failure shows the spinner again rather than leaving the failure up
    /// with nothing apparently happening.
    @Test func aRetryIsInFlightWhileItRuns() async {
        let series = StubDetails(details: severance, fails: true)
        let request = SeriesDetailsRequest(for: severanceMatch, series: series)
        await request.load()
        #expect(request.state == .failed)

        series.fails = false
        series.holdRequests()
        async let ran: Void = request.load()
        await series.requestStarted(95396)
        #expect(request.state == .loading)

        series.release(95396)
        await ran
    }

    // MARK: - What the stub answers with

    private var severanceMatch: SeriesMatch { SeriesMatch(id: 95396, name: "Severance") }

    private var severance: SeriesDetails {
        SeriesDetails(
            id: 95396,
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
}

private extension SeriesDetailsRequest {
    /// What is on screen, for the tests that are about what a request produced rather than
    /// which state it is in.
    var details: SeriesDetails? {
        guard case .loaded(let details) = state else { return nil }
        return details
    }
}

/// The BFF as a details request sees it, with nothing behind it. Pinned to the main actor,
/// which every caller of it here already is, so a test can read what was asked for and hold an
/// answer back mid-flight without a race of its own.
@MainActor
private final class StubDetails: SeriesSearching {
    var served: SeriesDetails?
    var fails: Bool
    var failure: BffError

    private(set) var asked: [Int] = []

    private var isHolding = false
    private var held: [Int: CheckedContinuation<Void, Never>] = [:]
    private var started: Set<Int> = []
    private var watchers: [CheckedContinuation<Void, Never>] = []

    init(details: SeriesDetails? = nil, fails: Bool = false, as failure: BffError = .notReached) {
        self.served = details
        self.fails = fails
        self.failure = failure
    }

    /// Nothing here searches: a details request never asks this.
    func series(matching text: String) async throws -> [SeriesMatch] { [] }

    func details(for id: Int) async throws -> SeriesDetails {
        asked.append(id)
        if isHolding {
            started.insert(id)
            wakeWatchers()
            await withCheckedContinuation { held[id] = $0 }
        }
        if fails { throw failure }
        guard let served else { throw BffError.notServed(status: 404) }
        return served
    }

    /// Makes every request from here on wait to be released, so a test can look at one
    /// mid-flight.
    func holdRequests() { isHolding = true }

    /// Returns once a held request for `id` has actually been asked for.
    func requestStarted(_ id: Int) async {
        while !started.contains(id) {
            await withCheckedContinuation { watchers.append($0) }
        }
    }

    /// Lets the held request for `id` answer.
    func release(_ id: Int) {
        started.remove(id)
        held.removeValue(forKey: id)?.resume()
    }

    private func wakeWatchers() {
        let waiting = watchers
        watchers = []
        for watcher in waiting { watcher.resume() }
    }
}
