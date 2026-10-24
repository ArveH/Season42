import Foundation
import Testing
@testable import Season42

/// Tests the Library Export at the `Library` seam: what the file says, read back as plain
/// JSON the way any other program the user hands it to would read it. Nothing here decodes
/// through the app's own types, so a renamed key is a failing test rather than a quiet
/// change to a file the user already keeps.
@MainActor
struct LibraryExportTests {
    @Test func anEmptyLibraryExportsAValidEmptyFile() throws {
        let library = try Library.inMemory()

        let file = try json(library.export())

        #expect(file["version"] as? Int == 1)
        #expect((file["streamingServices"] as? [Any])?.isEmpty == true)
        #expect((file["trackedSeries"] as? [Any])?.isEmpty == true)
        #expect((file["trackedMovies"] as? [Any])?.isEmpty == true)
    }

    // MARK: - Streaming Services

    @Test func everyServiceIsWrittenOnceWithItsNameAndLogo() throws {
        let library = try Library.inMemory()
        try library.addStreamingService(name: "Netflix", logo: Data([0xFF, 0xD8, 0xFF]))
        try library.addStreamingService(name: "Apple TV+")

        let services = try #require(json(library.export())["streamingServices"] as? [[String: Any]])

        #expect(services.map { $0["name"] as? String } == ["Apple TV+", "Netflix"])
        #expect(services[0]["logo"] is NSNull)
        #expect(services[1]["logo"] as? String == "/9j/")
    }

    // MARK: - Tracked Series

    @Test func aSeriesIsWrittenWithEveryFieldAndNamesItsService() throws {
        let clock = TestClock()
        let library = try Library.inMemory(now: clock.now)
        let series = try library.addTrackedSeries(
            title: "Severance",
            summary: "Work-life balance, surgically enforced.",
            poster: Data([0xFF, 0xD8, 0xFF]),
            seasons: [9, 10],
            status: .watching,
            position: Position(season: 2, episode: 2),
            streamingService: try library.service("Apple TV+"),
            nextEpisodeDate: TestClock.epoch + 86_400,
            releaseSlot: ReleaseSlot(weekday: 3, hour: 21, minute: 0)
        )
        clock.advance(by: 3_600)
        library.markNextEpisodeWatched(series)

        let file = try json(library.export())
        let written = try #require((file["trackedSeries"] as? [[String: Any]])?.first)

        #expect(written["title"] as? String == "Severance")
        #expect(written["description"] as? String == "Work-life balance, surgically enforced.")
        #expect(written["poster"] as? String == "/9j/")
        #expect(written["seasons"] as? [Int] == [9, 10])
        #expect(written["status"] as? String == "watching")
        let position = try #require(written["position"] as? [String: Int])
        #expect(position == ["season": 2, "episode": 3])
        #expect(written["streamingService"] as? String == "Apple TV+")
        #expect(written["nextEpisodeDate"] as? String == "2023-11-15T22:13:20Z")
        let slot = try #require(written["releaseSlot"] as? [String: Int])
        #expect(slot == ["weekday": 3, "minutesPastMidnight": 21 * 60])
        #expect(written["addedAt"] as? String == "2023-11-14T22:13:20Z")
        #expect(written["watchedAt"] as? String == "2023-11-14T23:13:20Z")
    }

    @Test func aSeriesWithNothingOptionalWritesNullsRatherThanLeavingFieldsOut() throws {
        let library = try Library.inMemory()
        try library.addTrackedSeries(title: "Andor", seasons: [12], status: .planned)

        let file = try json(library.export())
        let written = try #require((file["trackedSeries"] as? [[String: Any]])?.first)

        for field in ["poster", "position", "streamingService", "nextEpisodeDate", "releaseSlot", "watchedAt"] {
            #expect(written[field] is NSNull, "\(field)")
        }
    }

    // MARK: - Tracked Movies

    @Test func aMovieIsWrittenWithEveryFieldAndNamesItsService() throws {
        let clock = TestClock()
        let library = try Library.inMemory(now: clock.now)
        let movie = try library.addTrackedMovie(
            title: "Arrival",
            summary: "Linguistics, non-linearly.",
            poster: Data([0xFF, 0xD8, 0xFF]),
            streamingService: try library.service("Netflix")
        ).entry
        clock.advance(by: 3_600)
        library.setWatched(true, on: movie)

        let file = try json(library.export())
        let written = try #require((file["trackedMovies"] as? [[String: Any]])?.first)

        #expect(written["title"] as? String == "Arrival")
        #expect(written["description"] as? String == "Linguistics, non-linearly.")
        #expect(written["poster"] as? String == "/9j/")
        #expect(written["streamingService"] as? String == "Netflix")
        #expect(written["addedAt"] as? String == "2023-11-14T22:13:20Z")
        #expect(written["isWatched"] as? Bool == true)
        #expect(written["watchedAt"] as? String == "2023-11-14T23:13:20Z")
    }

    @Test func aMovieOnTheWatchlistWritesNullsRatherThanLeavingFieldsOut() throws {
        let library = try Library.inMemory()
        try library.addTrackedMovie(title: "Dune")

        let file = try json(library.export())
        let written = try #require((file["trackedMovies"] as? [[String: Any]])?.first)

        #expect(written["isWatched"] as? Bool == false)
        for field in ["poster", "streamingService", "watchedAt"] {
            #expect(written[field] is NSNull, "\(field)")
        }
    }

    // MARK: - The whole Library

    @Test func everyEntryInTheLibraryIsWritten() throws {
        let library = try Library.inMemory()
        try library.addTrackedSeries(title: "Severance", seasons: [9], status: .watching)
        try library.addTrackedSeries(title: "Andor", seasons: [12], status: .planned)
        try library.addTrackedMovie(title: "Arrival")
        try library.addTrackedMovie(title: "Dune")

        let file = try json(library.export())
        let series = try #require(file["trackedSeries"] as? [[String: Any]])
        let movies = try #require(file["trackedMovies"] as? [[String: Any]])

        #expect(Set(series.compactMap { $0["title"] as? String }) == ["Severance", "Andor"])
        #expect(Set(movies.compactMap { $0["title"] as? String }) == ["Arrival", "Dune"])
    }

    // MARK: - Reading the file

    private func json(_ data: Data) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
