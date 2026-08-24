import Foundation
import Testing
@testable import Season42

/// The Waiting section of the home tab, tested at the model facade: which series it lists
/// and the order they come back in. The view itself stays thin and untested.
@MainActor
struct WaitingTests {
    @Test func onlySeriesWithStatusWaitingAreListed() throws {
        let library = try Library.inMemory()
        for status in WatchStatus.allCases {
            try library.addTrackedSeries(title: status.title, seasons: [10], status: status)
        }

        #expect(library.waiting.map(\.title) == ["Waiting"])
    }

    @Test func theSoonestNextEpisodeDateIsListedFirst() throws {
        let library = try Library.inMemory()
        try library.addTrackedSeries(
            title: "Later",
            seasons: [10],
            status: .waiting,
            nextEpisodeDate: .day(20)
        )
        try library.addTrackedSeries(
            title: "Sooner",
            seasons: [10],
            status: .waiting,
            nextEpisodeDate: .day(10)
        )

        #expect(library.waiting.map(\.title) == ["Sooner", "Later"])
    }

    @Test func seriesWithoutANextEpisodeDateAreListedAfterTheDatedOnes() throws {
        let library = try Library.inMemory()
        try library.addTrackedSeries(title: "Dateless", seasons: [10], status: .waiting)
        try library.addTrackedSeries(
            title: "Dated",
            seasons: [10],
            status: .waiting,
            nextEpisodeDate: .day(30)
        )

        #expect(library.waiting.map(\.title) == ["Dated", "Dateless"])
    }

    @Test func seriesSharingANextEpisodeDateAreListedMostRecentlyAddedFirst() throws {
        let clock = TestClock()
        let library = try Library.inMemory(now: clock.now)
        try library.addTrackedSeries(
            title: "Older",
            seasons: [10],
            status: .waiting,
            nextEpisodeDate: .day(10)
        )
        clock.advance()
        try library.addTrackedSeries(
            title: "Newer",
            seasons: [10],
            status: .waiting,
            nextEpisodeDate: .day(10)
        )

        #expect(library.waiting.map(\.title) == ["Newer", "Older"])
    }

    @Test func datelessSeriesAreListedAmongThemselvesMostRecentlyAddedFirst() throws {
        let clock = TestClock()
        let library = try Library.inMemory(now: clock.now)
        try library.addTrackedSeries(title: "Older", seasons: [10], status: .waiting)
        clock.advance()
        try library.addTrackedSeries(title: "Newer", seasons: [10], status: .waiting)

        #expect(library.waiting.map(\.title) == ["Newer", "Older"])
    }

    @Test func aSeriesAnsweringWaitingToTheEndOfSeriesQuestionJoinsTheWaitingList() throws {
        let library = try Library.inMemory()
        let series = try library.addTrackedSeries(
            title: "Severance",
            seasons: [9, 10],
            status: .watching,
            position: Position(season: 2, episode: 10)
        )

        library.setStatus(.waiting, on: series)

        #expect(library.waiting.map(\.title) == ["Severance"])
        #expect(library.watching.isEmpty)
    }
}

private extension Date {
    /// A fixed date `day` days past the tests' epoch, so ordering never depends on today.
    static func day(_ day: Int) -> Date {
        TestClock.epoch.addingTimeInterval(Double(day) * 86_400)
    }
}
