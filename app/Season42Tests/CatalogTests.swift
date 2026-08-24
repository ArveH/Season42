import Foundation
import Testing
@testable import Season42

/// Tests the Catalog seam: decoding the bundled snapshot, filling the on-device Catalog
/// cache from it on a first launch, and leaving both a filled cache and the user's own
/// Library alone. The Catalog tab only lists what comes back from here.
@MainActor
struct CatalogTests {
    // MARK: - The bundled snapshot

    @Test func theBundledSnapshotDecodes() throws {
        let snapshot = try CatalogSnapshot.bundled()

        #expect(!snapshot.streamingServices.isEmpty)
        #expect(!snapshot.series.isEmpty)
        #expect(!snapshot.movies.isEmpty)
    }

    @Test func everySnapshotEntryCarriesWhatTheCatalogTabShows() throws {
        let snapshot = try CatalogSnapshot.bundled()

        for service in snapshot.streamingServices {
            #expect(!service.externalId.isEmpty)
            #expect(!service.name.isEmpty)
        }
        for series in snapshot.series {
            #expect(!series.externalId.isEmpty)
            #expect(!series.title.isEmpty)
            #expect(!series.summary.isEmpty)
            #expect(!series.seasons.isEmpty)
            #expect(series.seasons.firstSeasonWithoutEpisodes == nil)
        }
        for movie in snapshot.movies {
            #expect(!movie.externalId.isEmpty)
            #expect(!movie.title.isEmpty)
            #expect(!movie.summary.isEmpty)
        }
    }

    @Test func theSnapshotCarriesTheStreamingServicesTheUserWatchesOn() throws {
        let snapshot = try CatalogSnapshot.bundled()

        let names = snapshot.streamingServices.map(\.name)
        #expect(names.contains("Netflix"))
        #expect(names.contains("NRK TV"))
        #expect(names.contains("TV 2 Play"))
        #expect(names.contains("SkyShowtime"))
        #expect(names.contains("Discovery+"))
    }

    @Test func aSeriesSnapshotKeepsItsSeasonsInOrder() throws {
        let snapshot = try CatalogSnapshot.bundled()

        let bear = try #require(snapshot.series.first { $0.title == "The Bear" })
        #expect(bear.seasons.episodeCounts == [8, 10, 10, 10, 8])
        #expect(bear.seasons.episodeCount(inSeason: 2) == 10)
    }

    @Test func decodingRejectsJsonThatIsNotACatalog() {
        #expect(throws: (any Error).self) {
            try CatalogSnapshot(json: Data(#"{ "series": [] }"#.utf8))
        }
    }

    /// A Catalog Series the Library would refuse to store is one the Catalog may not
    /// serve either, and a snapshot is taken whole: one unusable series spoils it.
    @Test(arguments: ["[]", "[10, 0, 8]"])
    func decodingRejectsASeriesWithASeasonThatHasNoEpisodes(seasons: String) {
        let json = """
        {
          "streamingServices": [],
          "series": [{
            "externalId": "70523", "title": "Dark", "description": "A missing child.",
            "posterUrl": null, "seasons": \(seasons)
          }],
          "movies": []
        }
        """

        #expect(throws: (any Error).self) {
            try CatalogSnapshot(json: Data(json.utf8))
        }
    }

    // MARK: - Filling the cache

    @Test func aFirstLaunchFillsAnEmptyCacheFromTheSnapshot() throws {
        let catalog = try Catalog.inMemory()
        #expect(catalog.isEmpty)

        try catalog.fillFromBundledSnapshotIfEmpty()

        let snapshot = try CatalogSnapshot.bundled()
        #expect(catalog.series.map(\.title) == snapshot.series.map(\.title))
        #expect(catalog.movies.map(\.title) == snapshot.movies.map(\.title))
        #expect(catalog.streamingServices.map(\.name) == snapshot.streamingServices.map(\.name))
        #expect(!catalog.isEmpty)
    }

    @Test func theCacheKeepsWhatTheSeriesIsAboutAndHowManyEpisodesEachSeasonHas() throws {
        let catalog = try Catalog.inMemory()
        try catalog.fill(from: .justTheBear)

        let bear = try #require(catalog.series.first)
        #expect(bear.externalId == "136315")
        #expect(bear.title == "The Bear")
        #expect(bear.summary.hasPrefix("Carmy"))
        #expect(bear.seasons.episodeCounts == [8, 10])
        #expect(bear.posterUrl == "https://image.tmdb.org/t/p/w500/eKfVzzEazSIjJMrw9ADa2x8ksLz.jpg")
    }

    @Test func aRelaunchDoesNotFillACacheThatIsAlreadyThere() throws {
        let container = try Catalog.inMemoryContainer()
        let first = Catalog(container: container)
        try first.fill(from: .justTheBear)

        let relaunched = Catalog(container: container)
        try relaunched.fillFromBundledSnapshotIfEmpty()

        #expect(relaunched.series.map(\.title) == ["The Bear"])
    }

    @Test func aCachedCatalogSurvivesARelaunch() throws {
        let store = URL.temporaryDirectory.appending(path: "\(UUID()).store")
        let first = Catalog(container: try Catalog.container(at: store))
        try first.fill(from: .justTheBear)

        let relaunched = Catalog(container: try Catalog.container(at: store))

        #expect(relaunched.series.map(\.title) == ["The Bear"])
        #expect(relaunched.movies.map(\.title) == ["Past Lives"])
    }

    @Test func fillingAgainReplacesEverythingCached() throws {
        let catalog = try Catalog.inMemory()
        try catalog.fillFromBundledSnapshotIfEmpty()

        try catalog.fill(from: .justTheBear)

        #expect(catalog.series.map(\.title) == ["The Bear"])
        #expect(catalog.movies.map(\.title) == ["Past Lives"])
        #expect(catalog.streamingServices.map(\.name) == ["Netflix"])
    }

    @Test func theCacheListsEntriesInTheOrderTheCatalogServesThem() throws {
        let catalog = try Catalog.inMemory()
        let snapshot = try CatalogSnapshot.bundled()

        try catalog.fill(from: snapshot)

        #expect(catalog.series.map(\.title) == snapshot.series.map(\.title))
        #expect(catalog.movies.map(\.title) == snapshot.movies.map(\.title))
    }

    // MARK: - The Catalog is not the user's data

    @Test func theCatalogCacheHoldsNothingTheUserOwns() {
        let cached = Catalog.schema.entities.map(\.name)
        let owned = Library.schema.entities.map(\.name)

        #expect(Set(cached).isDisjoint(with: Set(owned)))
    }

    @Test func fillingTheCacheLeavesTheLibraryEmpty() throws {
        let library = try Library.inMemory()
        let catalog = try Catalog.inMemory()

        try catalog.fillFromBundledSnapshotIfEmpty()

        #expect(library.entries.isEmpty)
        #expect(!catalog.series.isEmpty)
    }
}

private extension CatalogSnapshot {
    /// A snapshot of a single series, movie and service — enough to tell one filling of
    /// the cache from another without leaning on what the bundled snapshot happens to say.
    static let justTheBear = CatalogSnapshot(
        streamingServices: [
            CatalogStreamingServiceSnapshot(externalId: "netflix", name: "Netflix")
        ],
        series: [
            CatalogSeriesSnapshot(
                externalId: "136315",
                title: "The Bear",
                summary: "Carmy, a young fine-dining chef, comes home to Chicago.",
                posterUrl: "https://image.tmdb.org/t/p/w500/eKfVzzEazSIjJMrw9ADa2x8ksLz.jpg",
                seasons: [8, 10]
            )
        ],
        movies: [
            CatalogMovieSnapshot(
                externalId: "666277",
                title: "Past Lives",
                summary: "Childhood friends reunited in New York decades later.",
                posterUrl: nil
            )
        ]
    )
}
