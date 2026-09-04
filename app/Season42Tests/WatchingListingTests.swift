import Foundation
import Testing
@testable import Season42

/// The Watching listing's rules, tested at the seam that owns them: which of the two
/// Watching Orders is in force, how each one orders the Tracked Series the Library hands
/// over, and where the choice is kept between launches. The view itself stays thin and
/// untested.
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

        #expect(listing.series.map(\.title) == ["Andor", "Severance"])

        clock.advance()
        library.markNextEpisodeWatched(severance)

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
}

/// A `UserDefaults` suite of this test's own, thrown away when the test is done, so a
/// choice made in one test is never the choice another test starts from.
@MainActor
final class TestDefaults {
    let suite: UserDefaults
    private let name: String

    init() throws {
        name = "WatchingListingTests.\(UUID().uuidString)"
        suite = try #require(UserDefaults(suiteName: name))
    }

    deinit {
        suite.removePersistentDomain(forName: name)
    }
}
