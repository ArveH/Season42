import Foundation
import Testing
@testable import Season42

/// The Watching listing's rules, tested at the seam that owns them: which of the two
/// Watching Orders is in force, how each one orders the Tracked Series the Library hands
/// over, where the choice is kept between launches, and how the tab's own Library Filter
/// narrows both listings without moving anything. The view itself stays thin and untested.
@MainActor
struct WatchingListingTests {
    // MARK: - Which order is in force

    @Test func lastWatchedIsTheOrderUntilTheUserPicksAnother() throws {
        let defaults = try TestDefaults()
        let listing = WatchingListing(library: try Library.inMemory(), defaults: defaults.suite)

        #expect(listing.order == .lastWatched)
    }

    @Test func onlySeriesWithStatusWatchingAreListed() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        for status in WatchStatus.allCases {
            try library.addTrackedSeries(title: status.title, seasons: [10], status: status)
        }
        let listing = WatchingListing(library: library, defaults: defaults.suite)

        #expect(listing.series.map(\.title) == ["Watching"])
    }

    // MARK: - Last watched

    @Test func lastWatchedListsTheMostRecentlyWatchedSeriesFirst() throws {
        let defaults = try TestDefaults()
        let clock = TestClock()
        let library = try Library.inMemory(now: clock.now)
        let severance = try library.addTrackedSeries(title: "Severance", seasons: [9], status: .watching)
        let andor = try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        let listing = WatchingListing(library: library, defaults: defaults.suite)

        clock.advance()
        library.markNextEpisodeWatched(severance)
        clock.advance()
        library.markNextEpisodeWatched(andor)
        listing.retake()

        #expect(listing.series.map(\.title) == ["Andor", "Severance"])

        clock.advance()
        library.markNextEpisodeWatched(severance)
        listing.retake()

        #expect(listing.series.map(\.title) == ["Severance", "Andor"])
    }

    @Test func lastWatchedListsSeriesWithoutAStampBelowTheOnesWithOneMostRecentlyAddedFirst() throws {
        let defaults = try TestDefaults()
        let clock = TestClock()
        let library = try Library.inMemory(now: clock.now)
        let severance = try library.addTrackedSeries(title: "Severance", seasons: [9], status: .watching)
        try library.addTrackedSeries(title: "Older", seasons: [12], status: .watching)
        clock.advance()
        try library.addTrackedSeries(title: "Newer", seasons: [12], status: .watching)
        let listing = WatchingListing(library: library, defaults: defaults.suite)

        clock.advance()
        library.markNextEpisodeWatched(severance)
        listing.retake()

        #expect(listing.series.map(\.title) == ["Severance", "Newer", "Older"])
    }

    // MARK: - Title

    @Test func titleListsSeriesAlphabeticallyWhateverTheirStamps() throws {
        let defaults = try TestDefaults()
        let clock = TestClock()
        let library = try Library.inMemory(now: clock.now)
        let severance = try library.addTrackedSeries(title: "Severance", seasons: [9], status: .watching)
        try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        try library.addTrackedSeries(title: "Fargo", seasons: [10], status: .watching)
        let listing = WatchingListing(library: library, defaults: defaults.suite)
        clock.advance()
        library.markNextEpisodeWatched(severance)

        listing.order = .title

        #expect(listing.series.map(\.title) == ["Andor", "Fargo", "Severance"])
    }

    @Test func titleOrdersWithoutRegardToCase() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        try library.addTrackedSeries(title: "Zoo", seasons: [10], status: .watching)
        try library.addTrackedSeries(title: "the office", seasons: [10], status: .watching)
        try library.addTrackedSeries(title: "Andor", seasons: [10], status: .watching)
        try library.addTrackedSeries(title: "The Office", seasons: [10], status: .watching)
        let listing = WatchingListing(library: library, defaults: defaults.suite)

        listing.order = .title

        let titles = listing.series.map(\.title)
        #expect(titles.first == "Andor")
        #expect(Set(titles[1...2]) == ["the office", "The Office"])
        #expect(titles.last == "Zoo")
    }

    @Test func titleOrdersWithoutRegardToDiacritics() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        try library.addTrackedSeries(title: "Fargo", seasons: [10], status: .watching)
        try library.addTrackedSeries(title: "Élite", seasons: [10], status: .watching)
        try library.addTrackedSeries(title: "Dark", seasons: [10], status: .watching)
        let listing = WatchingListing(library: library, defaults: defaults.suite)

        listing.order = .title

        #expect(listing.series.map(\.title) == ["Dark", "Élite", "Fargo"])
    }

    @Test func titleDoesNotStripALeadingThe() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        try library.addTrackedSeries(title: "The Bear", seasons: [10], status: .watching)
        try library.addTrackedSeries(title: "Severance", seasons: [10], status: .watching)
        try library.addTrackedSeries(title: "Bear", seasons: [10], status: .watching)
        let listing = WatchingListing(library: library, defaults: defaults.suite)

        listing.order = .title

        #expect(listing.series.map(\.title) == ["Bear", "Severance", "The Bear"])
    }

    // MARK: - Held still

    @Test func markingAnEpisodeWatchedLeavesEveryRowInPlace() throws {
        let defaults = try TestDefaults()
        let clock = TestClock()
        let library = try Library.inMemory(now: clock.now)
        let severance = try library.addTrackedSeries(title: "Severance", seasons: [9], status: .watching)
        let andor = try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        clock.advance()
        library.markNextEpisodeWatched(andor)
        let listing = WatchingListing(library: library, defaults: defaults.suite)
        #expect(listing.series.map(\.title) == ["Andor", "Severance"])

        clock.advance()
        library.markNextEpisodeWatched(severance)

        #expect(listing.series.map(\.title) == ["Andor", "Severance"])
    }

    @Test func takingAWatchBackLeavesEveryRowInPlace() throws {
        let defaults = try TestDefaults()
        let clock = TestClock()
        let library = try Library.inMemory(now: clock.now)
        let severance = try library.addTrackedSeries(title: "Severance", seasons: [9], status: .watching)
        let andor = try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        clock.advance()
        library.markNextEpisodeWatched(severance)
        clock.advance()
        library.markNextEpisodeWatched(andor)
        let listing = WatchingListing(library: library, defaults: defaults.suite)
        #expect(listing.series.map(\.title) == ["Andor", "Severance"])

        clock.advance()
        library.unwatchLastEpisode(severance)

        #expect(listing.series.map(\.title) == ["Andor", "Severance"])
    }

    @Test func editingASeriesLeavesEveryRowInPlace() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        let fargo = try library.addTrackedSeries(title: "Fargo", seasons: [10], status: .watching)
        let listing = WatchingListing(library: library, defaults: defaults.suite)
        listing.order = .title
        #expect(listing.series.map(\.title) == ["Andor", "Fargo"])

        try library.edit(fargo, title: "Aargo", seasons: [10], status: .watching)

        #expect(listing.series.map(\.title) == ["Andor", "Aargo"])
    }

    @Test func pickingAnOrderRetakesTheSnapshot() throws {
        let defaults = try TestDefaults()
        let clock = TestClock()
        let library = try Library.inMemory(now: clock.now)
        let severance = try library.addTrackedSeries(title: "Severance", seasons: [9], status: .watching)
        let andor = try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        clock.advance()
        library.markNextEpisodeWatched(andor)
        let listing = WatchingListing(library: library, defaults: defaults.suite)
        clock.advance()
        library.markNextEpisodeWatched(severance)
        #expect(listing.series.map(\.title) == ["Andor", "Severance"])

        listing.order = .title
        #expect(listing.series.map(\.title) == ["Andor", "Severance"])

        listing.order = .lastWatched
        #expect(listing.series.map(\.title) == ["Severance", "Andor"])
    }

    @Test func arrivingOnTheTabRetakesTheSnapshot() throws {
        let defaults = try TestDefaults()
        let clock = TestClock()
        let library = try Library.inMemory(now: clock.now)
        let severance = try library.addTrackedSeries(title: "Severance", seasons: [9], status: .watching)
        let andor = try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        clock.advance()
        library.markNextEpisodeWatched(andor)
        let listing = WatchingListing(library: library, defaults: defaults.suite)
        clock.advance()
        library.markNextEpisodeWatched(severance)
        #expect(listing.series.map(\.title) == ["Andor", "Severance"])

        listing.retake()

        #expect(listing.series.map(\.title) == ["Severance", "Andor"])
    }

    @Test func aSeriesDeletedWhileHeldStillDropsOutAndTheRestKeepTheirPlaces() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        try library.addTrackedSeries(title: "Fargo", seasons: [10], status: .watching)
        let andor = try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        try library.addTrackedSeries(title: "Severance", seasons: [9], status: .watching)
        let listing = WatchingListing(library: library, defaults: defaults.suite)
        #expect(listing.series.map(\.title) == ["Severance", "Andor", "Fargo"])

        library.delete(.series(andor))

        #expect(listing.series.map(\.title) == ["Severance", "Fargo"])
    }

    // MARK: - Lapsed Rows

    @Test func answeringFinishedLeavesTheRowInPlaceLapsed() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        try library.addTrackedSeries(title: "Fargo", seasons: [10], status: .watching)
        let andor = try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        try library.addTrackedSeries(title: "Severance", seasons: [9], status: .watching)
        let listing = WatchingListing(library: library, defaults: defaults.suite)

        library.setStatus(.finished, on: andor)

        #expect(listing.series.map(\.title) == ["Severance", "Andor", "Fargo"])
        #expect(listing.isLapsed(andor))
        #expect(listing.series.filter(listing.isLapsed).map(\.title) == ["Andor"])
    }

    @Test func answeringWaitingLapsesTheRowAndKeepsItOutOfTheWaitingListing() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        try library.addTrackedSeries(title: "Fargo", seasons: [10], status: .waiting)
        let andor = try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        let listing = WatchingListing(library: library, defaults: defaults.suite)
        #expect(listing.waiting.map(\.title) == ["Fargo"])

        library.setStatus(.waiting, on: andor)

        #expect(listing.series.map(\.title) == ["Andor"])
        #expect(listing.isLapsed(andor))
        #expect(listing.waiting.map(\.title) == ["Fargo"])
    }

    @Test func changingTheStatusInTheEditFormLapsesTheRowTheSameWay() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        let andor = try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        let listing = WatchingListing(library: library, defaults: defaults.suite)

        try library.edit(andor, title: "Andor", seasons: [12], status: .dropped)

        #expect(listing.series.map(\.title) == ["Andor"])
        #expect(listing.isLapsed(andor))
    }

    @Test func settingTheStatusBackToWatchingUnLapsesTheRowWhereItStands() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        try library.addTrackedSeries(title: "Fargo", seasons: [10], status: .watching)
        let andor = try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        try library.addTrackedSeries(title: "Severance", seasons: [9], status: .watching)
        let listing = WatchingListing(library: library, defaults: defaults.suite)
        library.setStatus(.finished, on: andor)

        library.setStatus(.watching, on: andor)

        #expect(listing.series.map(\.title) == ["Severance", "Andor", "Fargo"])
        #expect(!listing.isLapsed(andor))
    }

    @Test func retakingTheSnapshotSweepsLapsedRowsOut() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        try library.addTrackedSeries(title: "Fargo", seasons: [10], status: .watching)
        let andor = try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        let listing = WatchingListing(library: library, defaults: defaults.suite)
        library.setStatus(.waiting, on: andor)
        #expect(listing.series.map(\.title) == ["Andor", "Fargo"])

        listing.retake()

        #expect(listing.series.map(\.title) == ["Fargo"])
        #expect(listing.waiting.map(\.title) == ["Andor"])
    }

    @Test func aLapsedRowThatIsDeletedDropsOutAtOnce() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        try library.addTrackedSeries(title: "Fargo", seasons: [10], status: .watching)
        let andor = try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        let listing = WatchingListing(library: library, defaults: defaults.suite)
        library.setStatus(.finished, on: andor)

        library.delete(.series(andor))

        #expect(listing.series.map(\.title) == ["Fargo"])
    }

    @Test func lapsingWritesNothingToTheLibrary() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        let andor = try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        let listing = WatchingListing(library: library, defaults: defaults.suite)

        library.setStatus(.finished, on: andor)
        #expect(listing.isLapsed(andor))

        // A second listing over the same Library knows nothing of the lapse: the row is
        // derived from this listing's snapshot, and nothing about it was stored.
        let another = WatchingListing(library: library, defaults: defaults.suite)
        #expect(another.series.isEmpty)
        #expect(library.watching.isEmpty)
    }

    @Test func aSeriesTheSnapshotNeverHeldIsNotALapsedRow() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        let fargo = try library.addTrackedSeries(title: "Fargo", seasons: [10], status: .waiting)
        let listing = WatchingListing(library: library, defaults: defaults.suite)

        #expect(!listing.isLapsed(fargo))
        #expect(listing.waiting.map(\.title) == ["Fargo"])
    }

    // MARK: - Joined rows

    @Test func aWaitingSeriesSetToWatchingJoinsTheListingAtTheBottom() throws {
        let defaults = try TestDefaults()
        let clock = TestClock()
        let library = try Library.inMemory(now: clock.now)
        try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        let fargo = try library.addTrackedSeries(title: "Fargo", seasons: [10], status: .waiting)
        let severance = try library.addTrackedSeries(
            title: "Severance", seasons: [9], status: .watching
        )
        clock.advance()
        library.markNextEpisodeWatched(severance)
        let listing = WatchingListing(library: library, defaults: defaults.suite)
        #expect(listing.series.map(\.title) == ["Severance", "Andor"])

        library.setStatus(.watching, on: fargo)

        #expect(listing.series.map(\.title) == ["Severance", "Andor", "Fargo"])
        #expect(!listing.isLapsed(fargo))
        #expect(listing.waiting.isEmpty)
    }

    @Test func twoJoinersAreAppendedInTheOrderInForce() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        let severance = try library.addTrackedSeries(
            title: "Severance", seasons: [9], status: .waiting
        )
        let fargo = try library.addTrackedSeries(title: "Fargo", seasons: [10], status: .waiting)
        let listing = WatchingListing(library: library, defaults: defaults.suite)
        listing.order = .title

        library.setStatus(.watching, on: severance)
        library.setStatus(.watching, on: fargo)

        #expect(listing.series.map(\.title) == ["Andor", "Fargo", "Severance"])
    }

    @Test func aJoinedRowSetBackToWaitingReturnsToTheWaitingListingAtOnce() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        let fargo = try library.addTrackedSeries(title: "Fargo", seasons: [10], status: .waiting)
        let listing = WatchingListing(library: library, defaults: defaults.suite)
        library.setStatus(.watching, on: fargo)
        #expect(listing.series.map(\.title) == ["Andor", "Fargo"])

        library.setStatus(.waiting, on: fargo)

        #expect(listing.series.map(\.title) == ["Andor"])
        #expect(!listing.isLapsed(fargo))
        #expect(listing.waiting.map(\.title) == ["Fargo"])
    }

    @Test func retakingTheSnapshotSortsJoinersIn() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        try library.addTrackedSeries(title: "Severance", seasons: [9], status: .watching)
        let andor = try library.addTrackedSeries(title: "Andor", seasons: [12], status: .waiting)
        let listing = WatchingListing(library: library, defaults: defaults.suite)
        listing.order = .title
        library.setStatus(.watching, on: andor)
        #expect(listing.series.map(\.title) == ["Severance", "Andor"])

        listing.retake()

        #expect(listing.series.map(\.title) == ["Andor", "Severance"])
    }

    @Test func joiningWritesNothingToTheLibrary() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        let fargo = try library.addTrackedSeries(title: "Fargo", seasons: [10], status: .waiting)
        let listing = WatchingListing(library: library, defaults: defaults.suite)

        library.setStatus(.watching, on: fargo)
        #expect(listing.series.map(\.title) == ["Fargo"])

        // A fresh listing lists it too, but only because the Library says it is Watching:
        // the join itself left nothing behind but the Status change the user asked for.
        let another = WatchingListing(library: library, defaults: defaults.suite)
        #expect(another.series.map(\.title) == ["Fargo"])
        #expect(!another.isLapsed(fargo))
    }

    // MARK: - Where the choice is kept

    @Test func theChosenOrderSurvivesAnAppRelaunch() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        let listing = WatchingListing(library: library, defaults: defaults.suite)

        listing.order = .title

        let relaunched = WatchingListing(library: library, defaults: defaults.suite)
        #expect(relaunched.order == .title)
    }

    @Test func theChosenOrderIsNotKeptInTheLibrary() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        let listing = WatchingListing(library: library, defaults: defaults.suite)

        listing.order = .title

        let otherDefaults = try TestDefaults()
        let overTheSameLibrary = WatchingListing(library: library, defaults: otherDefaults.suite)
        #expect(overTheSameLibrary.order == .lastWatched)
    }

    @Test func aChoiceThatCannotBeReadFallsBackToLastWatched() throws {
        let defaults = try TestDefaults()
        defaults.suite.set("by-hunch", forKey: WatchingListing.orderKey)

        let listing = WatchingListing(library: try Library.inMemory(), defaults: defaults.suite)

        #expect(listing.order == .lastWatched)
    }

    // MARK: - Narrowing by title

    // The Watching tab's Library Filter: its own, offering the search text alone, and a
    // view over the held-still snapshot — it hides rows and moves nothing (ADR-0014). The
    // matching rule is `LibraryFilter`'s and is tested there, not again here.

    @Test func theSearchTextNarrowsTheWatchingListingToTitlesContainingIt() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        try library.addTrackedSeries(title: "Severance", seasons: [9], status: .watching)
        try library.addTrackedSeries(title: "Fargo", seasons: [10], status: .watching)
        let listing = WatchingListing(library: library, defaults: defaults.suite)

        listing.filter.searchText = "an"

        #expect(listing.series.map(\.title) == ["Severance", "Andor"])
    }

    @Test func theSameTextNarrowsTheWaitingListing() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        try library.addTrackedSeries(title: "Fargo", seasons: [10], status: .waiting)
        try library.addTrackedSeries(title: "The Bear", seasons: [8], status: .waiting)
        let listing = WatchingListing(library: library, defaults: defaults.suite)

        listing.filter.searchText = "bear"

        #expect(listing.series.isEmpty)
        #expect(listing.waiting.map(\.title) == ["The Bear"])
    }

    @Test func rowsThatRemainKeepTheSnapshotsOrderAndClearingRestoresEveryRowInItsPlace() throws {
        let defaults = try TestDefaults()
        let clock = TestClock()
        let library = try Library.inMemory(now: clock.now)
        let andor = try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        let fargo = try library.addTrackedSeries(title: "Fargo", seasons: [10], status: .watching)
        let severance = try library.addTrackedSeries(title: "Severance", seasons: [9], status: .watching)
        clock.advance()
        library.markNextEpisodeWatched(severance)
        clock.advance()
        library.markNextEpisodeWatched(andor)
        clock.advance()
        library.markNextEpisodeWatched(fargo)
        let listing = WatchingListing(library: library, defaults: defaults.suite)
        #expect(listing.series.map(\.title) == ["Fargo", "Andor", "Severance"])

        listing.filter.searchText = "an"
        #expect(listing.series.map(\.title) == ["Andor", "Severance"])

        listing.filter.searchText = ""
        #expect(listing.series.map(\.title) == ["Fargo", "Andor", "Severance"])
    }

    @Test func narrowingNeverRetakesTheSnapshot() throws {
        let defaults = try TestDefaults()
        let clock = TestClock()
        let library = try Library.inMemory(now: clock.now)
        let severance = try library.addTrackedSeries(title: "Severance", seasons: [9], status: .watching)
        let andor = try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        clock.advance()
        library.markNextEpisodeWatched(andor)
        let listing = WatchingListing(library: library, defaults: defaults.suite)
        clock.advance()
        library.markNextEpisodeWatched(severance)
        #expect(listing.series.map(\.title) == ["Andor", "Severance"])

        listing.filter.searchText = "n"
        #expect(listing.series.map(\.title) == ["Andor", "Severance"])

        listing.filter.searchText = ""
        #expect(listing.series.map(\.title) == ["Andor", "Severance"])
    }

    @Test func narrowingWritesNothing() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        try library.addTrackedSeries(title: "Fargo", seasons: [10], status: .watching)
        let listing = WatchingListing(library: library, defaults: defaults.suite)

        listing.filter.searchText = "andor"

        #expect(library.watching.count == 2)
        let another = WatchingListing(library: library, defaults: defaults.suite)
        #expect(another.series.count == 2)
    }

    @Test func aLapsedRowMatchesLikeAnyOtherRow() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        try library.addTrackedSeries(title: "Fargo", seasons: [10], status: .watching)
        let andor = try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        let listing = WatchingListing(library: library, defaults: defaults.suite)
        library.setStatus(.waiting, on: andor)

        listing.filter.searchText = "andor"

        #expect(listing.series.map(\.title) == ["Andor"])
        #expect(listing.isLapsed(andor))
        #expect(listing.waiting.isEmpty)
    }

    @Test func aJoinedRowMatchesLikeAnyOtherRow() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        let fargo = try library.addTrackedSeries(title: "Fargo", seasons: [10], status: .waiting)
        let listing = WatchingListing(library: library, defaults: defaults.suite)
        library.setStatus(.watching, on: fargo)

        listing.filter.searchText = "fargo"

        #expect(listing.series.map(\.title) == ["Fargo"])
        #expect(!listing.isLapsed(fargo))
    }

    @Test func retakingTheSnapshotKeepsTheFilter() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        try library.addTrackedSeries(title: "Fargo", seasons: [10], status: .watching)
        let listing = WatchingListing(library: library, defaults: defaults.suite)
        listing.filter.searchText = "fargo"

        listing.retake()
        #expect(listing.filter.searchText == "fargo")
        #expect(listing.series.map(\.title) == ["Fargo"])

        listing.order = .title
        #expect(listing.filter.searchText == "fargo")
        #expect(listing.series.map(\.title) == ["Fargo"])
    }

    @Test func aNewListingStartsWithNoFilter() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)
        let listing = WatchingListing(library: library, defaults: defaults.suite)
        listing.filter.searchText = "nothing like this"

        let relaunched = WatchingListing(library: library, defaults: defaults.suite)

        #expect(relaunched.filter == LibraryFilter())
        #expect(relaunched.series.map(\.title) == ["Andor"])
    }

    @Test func theListingIsEmptyOnlyWhenItHoldsNothingToListWhateverTheFilterSays() throws {
        let defaults = try TestDefaults()
        let library = try Library.inMemory()
        let empty = WatchingListing(library: library, defaults: defaults.suite)
        #expect(empty.isEmpty)

        try library.addTrackedSeries(title: "Andor", seasons: [12], status: .waiting)
        let listing = WatchingListing(library: library, defaults: defaults.suite)
        listing.filter.searchText = "nothing like this"

        #expect(!listing.isEmpty)
        #expect(listing.series.isEmpty)
        #expect(listing.waiting.isEmpty)
    }
}
