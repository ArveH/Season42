import Foundation
import Testing
@testable import Season42

/// The Watching tab's rules, tested at the model facade: what a "watched it" tap does to
/// a Position, what an un-watch undoes, when the app asks Finished-or-Waiting, and the
/// order the tab lists series in. The view itself stays thin and untested.
///
/// `nextEpisode`, `previousEpisode` and `isAtLastKnownEpisode` are read here on the series
/// the facade hands back: they are derived, read-only state the facade offers about a
/// Tracked Series, not a second seam. Every change still goes through `Library`.
@MainActor
struct WatchingTests {
    // MARK: - Advancing a Position

    @Test func markingAnEpisodeWatchedAdvancesThePositionByOne() throws {
        let library = try Library.inMemory()
        let series = try library.addTrackedSeries(
            title: "Severance",
            seasons: [9, 10],
            status: .watching,
            position: Position(season: 2, episode: 4)
        )

        library.markNextEpisodeWatched(series)

        #expect(series.position == Position(season: 2, episode: 5))
    }

    @Test func theNextEpisodeIsWhatTheButtonWouldMarkWatched() throws {
        let library = try Library.inMemory()
        let series = try library.addTrackedSeries(
            title: "Severance",
            seasons: [9, 10],
            status: .watching,
            position: Position(season: 2, episode: 4)
        )

        #expect(series.nextEpisode == Position(season: 2, episode: 5))
    }

    @Test func aSeriesWithNothingWatchedStartsAtSeasonOneEpisodeOne() throws {
        let library = try Library.inMemory()
        let series = try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)

        #expect(series.nextEpisode == Position(season: 1, episode: 1))

        library.markNextEpisodeWatched(series)

        #expect(series.position == Position(season: 1, episode: 1))
    }

    @Test func markingAnEpisodeStampsTheWatchedAtDate() throws {
        let clock = TestClock()
        let library = try Library.inMemory(now: clock.now)
        let series = try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)

        #expect(series.lastWatchedAt == nil)

        clock.advance()
        library.markNextEpisodeWatched(series)

        #expect(series.lastWatchedAt == clock.date)
    }

    @Test func finishingASeasonRollsOverToTheNextSeasonsFirstEpisode() throws {
        let library = try Library.inMemory()
        let series = try library.addTrackedSeries(
            title: "Severance",
            seasons: [9, 10],
            status: .watching,
            position: Position(season: 1, episode: 8)
        )

        library.markNextEpisodeWatched(series)
        #expect(series.position == Position(season: 1, episode: 9))

        library.markNextEpisodeWatched(series)
        #expect(series.position == Position(season: 2, episode: 1))
    }

    // MARK: - The last known episode

    @Test func atTheLastKnownEpisodeThereIsNoNextEpisodeToOffer() throws {
        let library = try Library.inMemory()
        let series = try library.addTrackedSeries(
            title: "Severance",
            seasons: [9, 10],
            status: .watching,
            position: Position(season: 2, episode: 10)
        )

        #expect(series.nextEpisode == nil)
        #expect(series.isAtLastKnownEpisode)
    }

    @Test func markingTheLastKnownEpisodeLeavesTheSeriesAskingFinishedOrWaiting() throws {
        let library = try Library.inMemory()
        let series = try library.addTrackedSeries(
            title: "Severance",
            seasons: [9, 10],
            status: .watching,
            position: Position(season: 2, episode: 9)
        )

        library.markNextEpisodeWatched(series)

        #expect(series.position == Position(season: 2, episode: 10))
        #expect(series.isAtLastKnownEpisode)
        #expect(series.status == .watching)
    }

    @Test func aSeriesShortOfTheLastKnownEpisodeIsNotAsked() throws {
        let library = try Library.inMemory()
        let series = try library.addTrackedSeries(
            title: "Severance",
            seasons: [9, 10],
            status: .watching,
            position: Position(season: 2, episode: 9)
        )

        #expect(!series.isAtLastKnownEpisode)
    }

    @Test func aSeriesWithNothingWatchedIsNotAsked() throws {
        let library = try Library.inMemory()
        let series = try library.addTrackedSeries(title: "Ghosts", seasons: [1], status: .watching)

        #expect(!series.isAtLastKnownEpisode)
    }

    @Test func thePositionStaysPutAtTheLastKnownEpisode() throws {
        let clock = TestClock()
        let library = try Library.inMemory(now: clock.now)
        let series = try library.addTrackedSeries(
            title: "Severance",
            seasons: [9, 10],
            status: .watching,
            position: Position(season: 2, episode: 10)
        )
        clock.advance()

        library.markNextEpisodeWatched(series)

        #expect(series.position == Position(season: 2, episode: 10))
        #expect(series.lastWatchedAt == nil)
    }

    @Test(arguments: [WatchStatus.finished, .waiting])
    func theAnswerToTheQuestionIsAppliedAndTheSeriesLeavesTheWatchingList(
        answer: WatchStatus
    ) throws {
        let library = try Library.inMemory()
        let series = try library.addTrackedSeries(
            title: "Severance",
            seasons: [9, 10],
            status: .watching,
            position: Position(season: 2, episode: 10)
        )

        library.setStatus(answer, on: series)

        #expect(series.status == answer)
        #expect(library.watching.isEmpty)
    }

    // MARK: - Un-watching

    @Test func unwatchingStepsThePositionBackOneEpisode() throws {
        let library = try Library.inMemory()
        let series = try library.addTrackedSeries(
            title: "Severance",
            seasons: [9, 10],
            status: .watching,
            position: Position(season: 2, episode: 5)
        )

        library.unwatchLastEpisode(series)

        #expect(series.position == Position(season: 2, episode: 4))
    }

    @Test func unwatchingCrossesASeasonBoundaryBackwards() throws {
        let library = try Library.inMemory()
        let series = try library.addTrackedSeries(
            title: "Severance",
            seasons: [9, 10],
            status: .watching,
            position: Position(season: 2, episode: 1)
        )

        library.unwatchLastEpisode(series)

        #expect(series.position == Position(season: 1, episode: 9))
    }

    @Test func unwatchingTheVeryFirstEpisodeLeavesNothingWatched() throws {
        let library = try Library.inMemory()
        let series = try library.addTrackedSeries(
            title: "Severance",
            seasons: [9, 10],
            status: .watching,
            position: Position(season: 1, episode: 1)
        )

        library.unwatchLastEpisode(series)

        #expect(series.position == nil)
    }

    @Test func unwatchingASeriesWithNothingWatchedChangesNothing() throws {
        let library = try Library.inMemory()
        let series = try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)

        library.unwatchLastEpisode(series)

        #expect(series.position == nil)
    }

    @Test func unwatchingATapThatEndedTheSeriesPutsTheQuestionAway() throws {
        let library = try Library.inMemory()
        let series = try library.addTrackedSeries(
            title: "Severance",
            seasons: [9, 10],
            status: .watching,
            position: Position(season: 2, episode: 10)
        )

        library.unwatchLastEpisode(series)

        #expect(!series.isAtLastKnownEpisode)
        #expect(series.nextEpisode == Position(season: 2, episode: 10))
    }

    // MARK: - What the Watching tab lists

    @Test func onlySeriesWithStatusWatchingAreListed() throws {
        let library = try Library.inMemory()
        for status in WatchStatus.allCases {
            try library.addTrackedSeries(title: status.title, seasons: [10], status: status)
        }

        #expect(library.watching.map(\.title) == ["Watching"])
    }

    @Test func theMostRecentlyWatchedSeriesIsListedFirst() throws {
        let clock = TestClock()
        let library = try Library.inMemory(now: clock.now)
        let severance = try library.addTrackedSeries(title: "Severance", seasons: [9], status: .watching)
        let andor = try library.addTrackedSeries(title: "Andor", seasons: [12], status: .watching)

        clock.advance()
        library.markNextEpisodeWatched(severance)
        clock.advance()
        library.markNextEpisodeWatched(andor)

        #expect(library.watching.map(\.title) == ["Andor", "Severance"])

        clock.advance()
        library.markNextEpisodeWatched(severance)

        #expect(library.watching.map(\.title) == ["Severance", "Andor"])
    }

    @Test func seriesNotWatchedYetAreListedBelowTheOnesWithAWatchedAtStamp() throws {
        let clock = TestClock()
        let library = try Library.inMemory(now: clock.now)
        let severance = try library.addTrackedSeries(title: "Severance", seasons: [9], status: .watching)
        try library.addTrackedSeries(title: "Older", seasons: [12], status: .watching)
        clock.advance()
        try library.addTrackedSeries(title: "Newer", seasons: [12], status: .watching)

        clock.advance()
        library.markNextEpisodeWatched(severance)

        #expect(library.watching.map(\.title) == ["Severance", "Newer", "Older"])
    }

    // MARK: - Persistence

    @Test func anAdvancedPositionAndItsStampSurviveAnAppRelaunch() throws {
        let storeURL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let clock = TestClock()

        let library = Library(container: try Library.container(at: storeURL), now: clock.now)
        let series = try library.addTrackedSeries(
            title: "Severance",
            seasons: [9, 10],
            status: .watching,
            position: Position(season: 1, episode: 9)
        )
        clock.advance()
        library.markNextEpisodeWatched(series)

        let relaunched = Library(container: try Library.container(at: storeURL))

        #expect(relaunched.watching.first?.position == Position(season: 2, episode: 1))
        #expect(relaunched.watching.first?.lastWatchedAt == clock.date)
    }
}

/// A clock the tests move by hand, so watched-at stamps can be asserted exactly and
/// ordering never depends on how fast two calls happen to run.
@MainActor
final class TestClock {
    /// Where every test's clock starts, and the fixed point any other test date hangs off.
    nonisolated static let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private(set) var date = TestClock.epoch

    /// Passed to `Library` as its source of "now".
    var now: @MainActor () -> Date { { self.date } }

    func advance(by seconds: TimeInterval = 60) {
        date += seconds
    }
}
