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

    // MARK: - A Release Slot ranks by the day it next lands on

    /// The listing exists to say what is back next, so a Slot is ranked by its coming
    /// occurrence among the dated ones rather than sent to the foot of the list — even
    /// though the row says the recurrence and never that day (ADR-0016).
    @Test func aReleaseSlotIsRankedByItsComingOccurrenceAmongTheDatedSeries() throws {
        let library = try waitingLibrary()
        try library.addTrackedSeries(
            title: "Later",
            seasons: [10],
            status: .waiting,
            nextEpisodeDate: .day(5)
        )
        try library.addTrackedSeries(
            title: "Sooner",
            seasons: [10],
            status: .waiting,
            nextEpisodeDate: .day(1)
        )
        // The epoch is a Tuesday, so Thursday is two days out — between the two dates.
        try library.addTrackedSeries(
            title: "Slotted",
            seasons: [10],
            status: .waiting,
            releaseSlot: ReleaseSlot(weekday: 5, hour: 21, minute: 0)
        )

        #expect(library.waiting.map(\.title) == ["Sooner", "Slotted", "Later"])
    }

    /// The occurrence rolls over at local midnight rather than at the Slot's own time, so a
    /// series airing today stays at the top for the whole of today — even once 21:00 has
    /// gone by — and drops only while nobody is looking (ADR-0016).
    @Test func aSlotFallingTodayIsRankedAsTodayForTheRestOfTheDayAndReRanksAfterMidnight() throws {
        let clock = TestClock()
        let library = try waitingLibrary(now: clock.now)
        try library.addTrackedSeries(
            title: "Tomorrow",
            seasons: [10],
            status: .waiting,
            nextEpisodeDate: .day(1)
        )
        // The epoch is a Tuesday evening, so this slot's hour has already gone by today.
        try library.addTrackedSeries(
            title: "Today",
            seasons: [10],
            status: .waiting,
            releaseSlot: ReleaseSlot(weekday: 3, hour: 21, minute: 0)
        )

        #expect(library.waiting.map(\.title) == ["Today", "Tomorrow"])

        clock.advance(by: 3600)
        #expect(library.waiting.map(\.title) == ["Today", "Tomorrow"])

        // Past midnight: the slot is now next Tuesday's, and the dated series is today's.
        clock.advance(by: 3600 * 2)
        #expect(library.waiting.map(\.title) == ["Tomorrow", "Today"])
    }

    /// A Next Episode Date carries no time of day, so a Slot's 21:00 is never compared
    /// against a precision the user did not enter: the same day is a tie, broken as it
    /// always was.
    @Test func aDatedAndASlottedSeriesOnTheSameDayFallToTheMostRecentlyAddedTieBreak() throws {
        let clock = TestClock()
        let library = try waitingLibrary(now: clock.now)
        try library.addTrackedSeries(
            title: "Older",
            seasons: [10],
            status: .waiting,
            nextEpisodeDate: .day(2)
        )
        clock.advance()
        try library.addTrackedSeries(
            title: "Newer",
            seasons: [10],
            status: .waiting,
            releaseSlot: ReleaseSlot(weekday: 5, hour: 21, minute: 0)
        )

        #expect(library.waiting.map(\.title) == ["Newer", "Older"])
    }

    /// Ranked by the Slot, matching what its row says — the date it also carries is kept
    /// and ignored.
    @Test func aSeriesWithBothIsRankedByItsReleaseSlot() throws {
        let library = try waitingLibrary()
        try library.addTrackedSeries(
            title: "Dated",
            seasons: [10],
            status: .waiting,
            nextEpisodeDate: .day(5)
        )
        try library.addTrackedSeries(
            title: "Both",
            seasons: [10],
            status: .waiting,
            nextEpisodeDate: .day(20),
            releaseSlot: ReleaseSlot(weekday: 5, hour: 21, minute: 0)
        )

        #expect(library.waiting.map(\.title) == ["Both", "Dated"])
    }

    @Test func aSeriesWithNeitherADateNorASlotIsStillListedLast() throws {
        let library = try waitingLibrary()
        try library.addTrackedSeries(title: "Nothing known", seasons: [10], status: .waiting)
        try library.addTrackedSeries(
            title: "Slotted",
            seasons: [10],
            status: .waiting,
            releaseSlot: ReleaseSlot(weekday: 5, hour: 21, minute: 0)
        )

        #expect(library.waiting.map(\.title) == ["Slotted", "Nothing known"])
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

@MainActor
private extension WaitingTests {
    /// A Library whose Waiting order is worked out in a calendar of the test's own, so
    /// which weekday the epoch falls on and where local midnight sits never depend on the
    /// machine running it.
    func waitingLibrary(
        now: @escaping @MainActor () -> Date = { TestClock.epoch }
    ) throws -> Library {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return try Library.inMemory(now: now, calendar: calendar)
    }
}

private extension Date {
    /// A fixed date `day` days past the tests' epoch, so ordering never depends on today.
    static func day(_ day: Int) -> Date {
        TestClock.epoch.addingTimeInterval(Double(day) * 86_400)
    }
}
