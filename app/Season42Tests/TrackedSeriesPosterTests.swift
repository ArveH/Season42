import Foundation
import Testing
@testable import Season42

/// Tests the Poster where it is kept: on the Tracked Series itself, as bytes. Bytes and not a
/// link, so a series adopted once goes on drawing with the BFF stopped, unreachable or never
/// deployed — which is what these assert by never having one at all.
@MainActor
struct TrackedSeriesPosterTests {
    private let poster = Data("a poster".utf8)
    private let another = Data("another poster".utf8)

    @Test func aSeriesAddedWithAPosterKeepsTheBytes() throws {
        let library = try Library.inMemory()

        let series = try library.addTrackedSeries(
            title: "Severance",
            poster: poster,
            seasons: [9],
            status: .planned
        )

        #expect(series.poster == poster)
    }

    /// Every series entered by hand, which is every one until a copy brings a picture.
    @Test func aSeriesAddedWithoutOneHasNoPoster() throws {
        let library = try Library.inMemory()

        let series = try library.addTrackedSeries(title: "Severance", seasons: [9], status: .planned)

        #expect(series.poster == nil)
    }

    /// An edit rewrites the series whole, so a Poster left out of one is cleared — which is
    /// what Remove on the form is.
    @Test func anEditWithNoPosterClearsTheOneTheSeriesHad() throws {
        let library = try Library.inMemory()
        let series = try library.addTrackedSeries(
            title: "Severance",
            poster: poster,
            seasons: [9],
            status: .planned
        )

        try library.updateTrackedSeries(
            series,
            title: "Severance",
            summary: "",
            poster: nil,
            seasons: [9],
            status: .planned,
            position: nil,
            streamingService: nil,
            nextEpisodeDate: nil,
            releaseSlot: nil
        )

        #expect(series.poster == nil)
    }

    @Test func anEditCanPutADifferentPosterOnTheSeries() throws {
        let library = try Library.inMemory()
        let series = try library.addTrackedSeries(
            title: "Severance",
            poster: poster,
            seasons: [9],
            status: .planned
        )

        try library.updateTrackedSeries(
            series,
            title: "Severance",
            summary: "",
            poster: another,
            seasons: [9],
            status: .planned,
            position: nil,
            streamingService: nil,
            nextEpisodeDate: nil,
            releaseSlot: nil
        )

        #expect(series.poster == another)
    }

    /// The whole point of keeping bytes rather than an id: what was adopted is in the store,
    /// and nothing has to be asked for it again (ADR-0013).
    @Test func anAdoptedPosterSurvivesAnAppRelaunch() throws {
        let storeURL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let library = Library(container: try Library.container(at: storeURL))
        try library.addTrackedSeries(
            title: "Severance",
            poster: poster,
            seasons: [9],
            status: .planned
        )

        let relaunched = Library(container: try Library.container(at: storeURL))

        #expect(relaunched.trackedSeries.first?.poster == poster)
    }
}
