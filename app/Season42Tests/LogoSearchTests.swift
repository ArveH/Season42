import Foundation
import Testing
@testable import Season42

/// Tests the search seam: what a search for a Logo does with what the BFF answers, and
/// what adopting and removing one leaves behind. Everything here runs against a stub —
/// only `BffClient` needs a network, and it holds no rules for a test to check.
@MainActor
struct LogoSearchTests {
    // MARK: - Running a search

    @Test func aSearchStartsOutIdle() {
        let search = LogoSearch(name: "", logos: StubLogos())

        #expect(search.state == .idle)
    }

    @Test func aSearchShowsWhatItMatched() async {
        let search = LogoSearch(name: "net", logos: StubLogos(providers: [netflix]))

        await search.search()

        #expect(search.state == .results([WatchProviderMatch(provider: netflix, logo: bytes)]))
    }

    @Test func aSearchSearchesForWhatIsTyped() async {
        let logos = StubLogos(providers: [netflix])
        let search = LogoSearch(name: "  net  ", logos: logos)

        await search.search()

        #expect(logos.searched == ["net"])
    }

    @Test func aSearchOnABlankFieldDoesNothing() async {
        let logos = StubLogos(providers: [netflix])
        let search = LogoSearch(name: "   ", logos: logos)

        await search.search()

        #expect(logos.searched.isEmpty)
        #expect(search.state == .idle)
    }

    /// The state a spinner is keyed off, seen while the answer is still owed.
    @Test func aSearchInFlightSaysSo() async {
        let logos = StubLogos(providers: [netflix])
        logos.holdSearches()
        let search = LogoSearch(name: "net", logos: logos)

        async let ran: Void = search.search()
        await logos.searchStarted("net")
        #expect(search.state == .searching)

        logos.release("net")
        await ran
        #expect(search.state != .searching)
    }

    /// A slow first search answering after a second one has already landed must not
    /// replace it: results under a name they didn't come from are worse than nothing.
    @Test func aSearchOvertakenByANewerOneNeverLands() async {
        let logos = StubLogos()
        logos.answers = ["net": [netflix], "sky": [skyShowtime]]
        logos.holdSearches()
        let search = LogoSearch(name: "net", logos: logos)

        async let overtaken: Void = search.search()
        await logos.searchStarted("net")
        search.name = "sky"
        async let newer: Void = search.search()
        await logos.searchStarted("sky")

        logos.release("sky")
        await newer
        #expect(search.results.map(\.name) == ["SkyShowtime"])

        logos.release("net")
        await overtaken
        #expect(search.results.map(\.name) == ["SkyShowtime"])
    }

    @Test func aSearchThatMatchesNothingIsNotAFailure() async {
        let search = LogoSearch(name: "zzz", logos: StubLogos(providers: []))

        await search.search()

        #expect(search.state == .matchedNothing)
    }

    @Test func aSearchThatCouldNotBeRunFails() async {
        let search = LogoSearch(name: "net", logos: StubLogos(searchFails: true))

        await search.search()

        #expect(search.state == .failed)
    }

    /// The results are the BFF's order — TMDB's display priority — not the app's.
    @Test func resultsKeepTheOrderTheyWereServedIn() async {
        let search = LogoSearch(name: "s", logos: StubLogos(providers: [netflix, skyShowtime, nrk]))

        await search.search()

        #expect(search.results.map(\.name) == ["Netflix", "SkyShowtime", "NRK TV"])
    }

    /// Nothing filters a search against what the user has already registered: the BFF
    /// answers about TMDB, and a name they already have is `Library`'s refusal to make
    /// when they save.
    @Test func resultsAreNotFilteredAgainstAnythingTheAppKnows() async {
        let search = LogoSearch(name: "net", logos: StubLogos(providers: [netflix]))

        await search.search()

        #expect(search.results.map(\.name) == ["Netflix"])
    }

    @Test func aResultWhoseLogoCouldNotBeFetchedIsStillAResult() async {
        let logos = StubLogos(providers: [netflix])
        logos.logoFails = true
        let search = LogoSearch(name: "net", logos: logos)

        await search.search()

        #expect(search.results.map(\.name) == ["Netflix"])
        #expect(search.results.first?.logo == nil)
    }

    @Test func aSecondSearchReplacesTheFirstOnesResults() async {
        let logos = StubLogos(providers: [netflix])
        let search = LogoSearch(name: "net", logos: logos)
        await search.search()

        logos.served = []
        await search.search()

        #expect(search.state == .matchedNothing)
    }

    // MARK: - Adopting a result

    @Test func adoptingAResultTakesItsLogoAndItsName() async {
        let search = LogoSearch(name: "net", logos: StubLogos(providers: [netflix]))
        await search.search()

        search.adopt(search.results[0])

        #expect(search.name == "Netflix")
        #expect(search.logo == bytes)
        #expect(search.hasLogo)
    }

    /// The name stays the user's after adopting: the Logo does not own it.
    @Test func theNameCanBeChangedAfterAdoptingALogo() async {
        let search = LogoSearch(name: "net", logos: StubLogos(providers: [netflix]))
        await search.search()
        search.adopt(search.results[0])

        search.name = "Netflix (family)"

        #expect(search.name == "Netflix (family)")
        #expect(search.logo == bytes)
    }

    @Test func adoptingASecondResultReplacesTheFirst() async {
        let search = LogoSearch(name: "s", logos: StubLogos(providers: [netflix, skyShowtime]))
        await search.search()

        search.adopt(search.results[0])
        search.adopt(search.results[1])

        #expect(search.name == "SkyShowtime")
        #expect(search.logo == bytes)
    }

    @Test func adoptingLeavesTheResultsOnScreen() async {
        let search = LogoSearch(name: "s", logos: StubLogos(providers: [netflix, skyShowtime]))
        await search.search()

        search.adopt(search.results[0])

        #expect(search.results.count == 2)
    }

    @Test func adoptingAResultWithNoLogoLeavesNoneToRemove() async {
        let logos = StubLogos(providers: [netflix])
        logos.logoFails = true
        let search = LogoSearch(name: "net", logos: logos)
        await search.search()

        search.adopt(search.results[0])

        #expect(search.name == "Netflix")
        #expect(!search.hasLogo)
    }

    // MARK: - The Logo the sheet opened with

    @Test func renamingAServiceOpensWithItsNameAndItsLogo() {
        let search = LogoSearch(name: "Netflix", logo: bytes, logos: StubLogos())

        #expect(search.name == "Netflix")
        #expect(search.logo == bytes)
    }

    @Test func aSearchThatIsAbandonedLeavesTheLogoAlone() async {
        let logos = StubLogos(providers: [skyShowtime])
        let search = LogoSearch(name: "Netflix", logo: bytes, logos: logos)

        await search.search()

        #expect(search.logo == bytes)
    }

    @Test func aFailedSearchLeavesTheLogoAlone() async {
        let search = LogoSearch(name: "Netflix", logo: bytes, logos: StubLogos(searchFails: true))

        await search.search()

        #expect(search.state == .failed)
        #expect(search.logo == bytes)
    }

    // MARK: - Removing a Logo

    @Test func aServiceWithNoLogoHasNothingToRemove() {
        #expect(!LogoSearch(name: "NRK TV", logos: StubLogos()).hasLogo)
    }

    @Test func removingALogoLeavesTheNameAlone() {
        let search = LogoSearch(name: "Netflix (family)", logo: bytes, logos: StubLogos())

        search.removeLogo()

        #expect(!search.hasLogo)
        #expect(search.logo == nil)
        #expect(search.name == "Netflix (family)")
    }

    @Test func removingALogoLeavesTheResultsToAdoptAnotherFrom() async {
        let search = LogoSearch(name: "s", logos: StubLogos(providers: [netflix, skyShowtime]))
        await search.search()
        search.adopt(search.results[0])

        search.removeLogo()

        #expect(search.results.count == 2)
    }

    // MARK: - What the stub answers with

    private var netflix: WatchProvider { WatchProvider(name: "Netflix", logoPath: "/netflix.jpg") }
    private var skyShowtime: WatchProvider { WatchProvider(name: "SkyShowtime", logoPath: "/sky.jpg") }
    private var nrk: WatchProvider { WatchProvider(name: "NRK TV", logoPath: "/nrk.jpg") }

    private var bytes: Data { StubLogos.logoBytes }
}

private extension LogoSearch {
    /// The matches on screen, for the tests that are about what a search produced rather
    /// than which state it is in.
    var results: [WatchProviderMatch] {
        guard case .results(let matches) = state else { return [] }
        return matches
    }
}

/// The BFF as a search sees it, with nothing behind it. Pinned to the main actor, which
/// every caller of it here already is, so a test can read what was searched for and hold
/// an answer back mid-flight without a race of its own.
@MainActor
private final class StubLogos: LogoSearching {
    static let logoBytes = Data("logo".utf8)

    /// What every search answers with, for the tests that run only one.
    var served: [WatchProvider]

    /// What a particular search text answers with, for the tests that run two.
    var answers: [String: [WatchProvider]] = [:]

    var searchFails: Bool
    var logoFails = false

    private(set) var searched: [String] = []

    private var isHolding = false
    private var held: [String: CheckedContinuation<Void, Never>] = [:]
    private var started: Set<String> = []
    private var watchers: [CheckedContinuation<Void, Never>] = []

    init(providers: [WatchProvider] = [], searchFails: Bool = false) {
        self.served = providers
        self.searchFails = searchFails
    }

    func providers(matching text: String) async throws -> [WatchProvider] {
        searched.append(text)
        if isHolding {
            started.insert(text)
            wakeWatchers()
            await withCheckedContinuation { held[text] = $0 }
        }
        if searchFails { throw BffError.notServed(status: 503) }
        return answers[text] ?? served
    }

    func logo(at path: String) async throws -> Data {
        if logoFails { throw BffError.notServed(status: 404) }
        return Self.logoBytes
    }

    /// Makes every search from here on wait to be released, so a test can look at a
    /// search mid-flight and choose which of two answers lands first.
    func holdSearches() { isHolding = true }

    /// Returns once a held search for `text` has actually been asked for.
    func searchStarted(_ text: String) async {
        while !started.contains(text) {
            await withCheckedContinuation { watchers.append($0) }
        }
    }

    /// Lets the held search for `text` answer.
    func release(_ text: String) {
        held.removeValue(forKey: text)?.resume()
    }

    private func wakeWatchers() {
        let waiting = watchers
        watchers = []
        for watcher in waiting { watcher.resume() }
    }
}
