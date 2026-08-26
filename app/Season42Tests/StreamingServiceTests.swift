import Foundation
import Testing
@testable import Season42

@MainActor
struct StreamingServiceTests {
    // MARK: - Registering

    @Test func aRegisteredServiceIsListedByName() throws {
        let library = try Library.inMemory()

        let service = try library.addStreamingService(name: "Netflix")

        #expect(service.name == "Netflix")
        #expect(library.streamingServices.map(\.name) == ["Netflix"])
    }

    @Test func surroundingWhitespaceIsTrimmedFromTheName() throws {
        let library = try Library.inMemory()

        let service = try library.addStreamingService(name: "  Netflix  ")

        #expect(service.name == "Netflix")
    }

    @Test(arguments: ["", "   "])
    func aServiceWithoutANameIsRejected(name: String) throws {
        let library = try Library.inMemory()

        #expect(throws: LibraryError.streamingServiceNameIsBlank) {
            try library.addStreamingService(name: name)
        }
        #expect(library.streamingServices.isEmpty)
    }

    /// Two services spelled the same way but for their case are the one service — which is
    /// the whole point of registering them rather than typing a name onto every entry.
    @Test(arguments: ["Netflix", "netflix", "NETFLIX"])
    func aServiceAlreadyRegisteredIsRejectedWhateverItsCase(name: String) throws {
        let library = try Library.inMemory()
        try library.addStreamingService(name: "Netflix")

        #expect(throws: LibraryError.streamingServiceAlreadyExists(name: name)) {
            try library.addStreamingService(name: name)
        }
        #expect(library.streamingServices.count == 1)
    }

    @Test func servicesAreListedAlphabeticallyHoweverTheyWereRegistered() throws {
        let library = try Library.inMemory()

        try library.addStreamingService(name: "Viaplay")
        try library.addStreamingService(name: "Apple TV+")
        try library.addStreamingService(name: "NRK TV")

        #expect(library.streamingServices.map(\.name) == ["Apple TV+", "NRK TV", "Viaplay"])
    }

    // MARK: - Renaming

    /// An entry names the service itself, not a copy of its name, so a rename reaches
    /// every entry on it at once. This is what a registered service buys over free text.
    @Test func renamingAServiceRenamesItOnEveryEntryThatNamesIt() throws {
        let library = try Library.inMemory()
        let service = try library.addStreamingService(name: "HBO Max")
        let series = try library.addTrackedSeries(
            title: "Succession",
            seasons: [10],
            status: .finished,
            streamingService: service
        )
        let movie = try library.addTrackedMovie(title: "Dune", streamingService: service)

        try library.renameStreamingService(service, to: "Max")

        #expect(series.streamingService?.name == "Max")
        #expect(movie.streamingService?.name == "Max")
    }

    @Test func aServiceCanBeRestyledToADifferentCaseOfItsOwnName() throws {
        let library = try Library.inMemory()
        let service = try library.addStreamingService(name: "netflix")

        try library.renameStreamingService(service, to: "Netflix")

        #expect(service.name == "Netflix")
    }

    @Test func renamingAServiceToOneAlreadyRegisteredIsRejected() throws {
        let library = try Library.inMemory()
        try library.addStreamingService(name: "Netflix")
        let service = try library.addStreamingService(name: "Viaplay")

        #expect(throws: LibraryError.streamingServiceAlreadyExists(name: "netflix")) {
            try library.renameStreamingService(service, to: "netflix")
        }
        #expect(service.name == "Viaplay")
    }

    @Test(arguments: ["", "   "])
    func renamingAServiceToNothingIsRejected(name: String) throws {
        let library = try Library.inMemory()
        let service = try library.addStreamingService(name: "Netflix")

        #expect(throws: LibraryError.streamingServiceNameIsBlank) {
            try library.renameStreamingService(service, to: name)
        }
        #expect(service.name == "Netflix")
    }

    // MARK: - Deleting

    /// Cancelling a subscription says nothing about what the user tracks (ADR-0006): the
    /// entries stay, and are simply left watching nowhere.
    @Test func deletingAServiceLeavesTheEntriesThatNamedItWithNoService() throws {
        let library = try Library.inMemory()
        let service = try library.addStreamingService(name: "Viaplay")
        let series = try library.addTrackedSeries(
            title: "Occupied",
            seasons: [8],
            status: .watching,
            streamingService: service
        )
        let movie = try library.addTrackedMovie(title: "The Wave", streamingService: service)

        library.deleteStreamingService(service)

        #expect(library.streamingServices.isEmpty)
        #expect(library.entries.count == 2)
        #expect(series.streamingService == nil)
        #expect(movie.streamingService == nil)
    }

    @Test func deletingAServiceLeavesTheEntriesOnOtherServicesAlone() throws {
        let library = try Library.inMemory()
        let viaplay = try library.addStreamingService(name: "Viaplay")
        let netflix = try library.addStreamingService(name: "Netflix")
        let series = try library.addTrackedSeries(
            title: "Dark",
            seasons: [10],
            status: .finished,
            streamingService: netflix
        )

        library.deleteStreamingService(viaplay)

        #expect(series.streamingService === netflix)
    }

    /// What the tab shows beside a service, and what its delete confirmation counts.
    @Test func aServiceCountsEveryEntryThatNamesIt() throws {
        let library = try Library.inMemory()
        let service = try library.addStreamingService(name: "Netflix")
        try library.addTrackedSeries(
            title: "Dark",
            seasons: [10],
            status: .finished,
            streamingService: service
        )
        try library.addTrackedMovie(title: "Okja", streamingService: service)
        try library.addTrackedMovie(title: "Dune")

        #expect(service.entryCount == 2)
    }

    // MARK: - The Logo

    /// A Logo is bytes on the service, so a service registered with one hands it back
    /// without anything else being asked for it.
    @Test func aServiceRegisteredWithALogoKeepsIt() throws {
        let library = try Library.inMemory()

        let service = try library.addStreamingService(name: "Netflix", logo: .logo)

        #expect(service.logo == .logo)
        #expect(library.streamingServices.first?.logo == .logo)
    }

    @Test func aServiceRegisteredWithoutALogoHasNone() throws {
        let library = try Library.inMemory()

        let service = try library.addStreamingService(name: "Netflix")

        #expect(service.logo == nil)
    }

    @Test func aLogoCanBeAdoptedOntoAServiceThatHadNone() throws {
        let library = try Library.inMemory()
        let service = try library.addStreamingService(name: "Netflix")

        library.setLogo(.logo, on: service)

        #expect(service.logo == .logo)
    }

    @Test func adoptingASecondLogoReplacesTheFirst() throws {
        let library = try Library.inMemory()
        let service = try library.addStreamingService(name: "Netflix", logo: .logo)

        library.setLogo(.otherLogo, on: service)

        #expect(service.logo == .otherLogo)
    }

    @Test func aLogoCanBeClearedFromAServiceThatHadOne() throws {
        let library = try Library.inMemory()
        let service = try library.addStreamingService(name: "Netflix", logo: .logo)

        library.setLogo(nil, on: service)

        #expect(service.logo == nil)
    }

    /// A Logo is adopted onto the service, not derived from its name (ADR-0007), so the
    /// user renaming one says nothing about the picture on it.
    @Test func renamingAServiceLeavesItsLogoAlone() throws {
        let library = try Library.inMemory()
        let service = try library.addStreamingService(name: "HBO Max", logo: .logo)

        try library.renameStreamingService(service, to: "Max")

        #expect(service.logo == .logo)
    }

    /// A refused rename changes nothing, the Logo included.
    @Test func aRefusedRenameLeavesTheLogoAlone() throws {
        let library = try Library.inMemory()
        try library.addStreamingService(name: "Netflix")
        let service = try library.addStreamingService(name: "Viaplay", logo: .logo)

        #expect(throws: LibraryError.streamingServiceAlreadyExists(name: "Netflix")) {
            try library.renameStreamingService(service, to: "Netflix")
        }
        #expect(service.logo == .logo)
    }

    /// Deleting a service with a Logo is deleting a service: the entries on it are left
    /// naming none rather than taken with it (ADR-0006).
    @Test func deletingAServiceWithALogoStillLeavesItsEntriesWithNoService() throws {
        let library = try Library.inMemory()
        let service = try library.addStreamingService(name: "Netflix", logo: .logo)
        let series = try library.addTrackedSeries(
            title: "Dark",
            seasons: [10],
            status: .finished,
            streamingService: service
        )

        #expect(service.entryCount == 1)
        library.deleteStreamingService(service)

        #expect(library.streamingServices.isEmpty)
        #expect(series.streamingService == nil)
    }

    /// Nothing about a Logo is on disk beyond the bytes, so a store written before there
    /// were Logos opens as a store of services with none.
    @Test func aServiceStoredBeforeLogosExistedOpensWithNone() throws {
        let container = try Library.inMemoryContainer()
        let library = Library(container: container)
        try library.addStreamingService(name: "Netflix")

        let reopened = Library(container: container)

        #expect(reopened.streamingServices.map(\.logo) == [nil])
    }

    @Test func anAdoptedLogoSurvivesAnAppRelaunch() throws {
        let storeURL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let library = Library(container: try Library.container(at: storeURL))
        try library.addStreamingService(name: "Netflix", logo: .logo)

        let relaunched = Library(container: try Library.container(at: storeURL))

        #expect(relaunched.streamingServices.first?.logo == .logo)
    }

    // MARK: - Adopting the names typed before services were registered

    @Test func aHandTypedServiceNameBecomesARegisteredServiceOnTheNextOpen() throws {
        let container = try Library.inMemoryContainer()
        let library = Library(container: container)
        let series = try library.addTrackedSeries(title: "Dark", seasons: [10], status: .finished)
        series.legacyStreamingServiceName = "Netflix"

        let reopened = Library(container: container)

        #expect(reopened.streamingServices.map(\.name) == ["Netflix"])
        #expect(series.streamingService?.name == "Netflix")
        #expect(series.legacyStreamingServiceName == nil)
    }

    @Test func handTypedNamesAcrossSeriesAndMoviesBecomeOneServiceEach() throws {
        let container = try Library.inMemoryContainer()
        let library = Library(container: container)
        let series = try library.addTrackedSeries(title: "Dark", seasons: [10], status: .finished)
        series.legacyStreamingServiceName = "Netflix"
        let movie = try library.addTrackedMovie(title: "Okja")
        movie.legacyStreamingServiceName = "Netflix"
        let other = try library.addTrackedMovie(title: "Severance: The Film")
        other.legacyStreamingServiceName = "Apple TV+"

        let reopened = Library(container: container)

        #expect(reopened.streamingServices.map(\.name) == ["Apple TV+", "Netflix"])
        #expect(series.streamingService === movie.streamingService)
    }

    /// Names that differ only in case were always the one service; the spelling that wins
    /// is the one on the most recently added entry, being the user's latest word on it.
    @Test func handTypedNamesDifferingOnlyInCaseBecomeOneServiceSpelledTheNewestWay() throws {
        var clock = Date(timeIntervalSince1970: 1_700_000_000)
        let container = try Library.inMemoryContainer()
        let library = Library(container: container, now: { clock })
        let older = try library.addTrackedMovie(title: "Okja")
        older.legacyStreamingServiceName = "netflix"
        clock = clock.addingTimeInterval(3600)
        let newer = try library.addTrackedMovie(title: "Dune")
        newer.legacyStreamingServiceName = "Netflix"

        let reopened = Library(container: container)

        #expect(reopened.streamingServices.map(\.name) == ["Netflix"])
        #expect(older.streamingService === newer.streamingService)
    }

    /// A name of nothing but whitespace meant "no service" when it was typed, and there is
    /// no service worth registering in it now.
    @Test func aBlankHandTypedNameLeavesTheEntryWithNoService() throws {
        let container = try Library.inMemoryContainer()
        let library = Library(container: container)
        let movie = try library.addTrackedMovie(title: "Dune")
        movie.legacyStreamingServiceName = "   "

        let reopened = Library(container: container)

        #expect(reopened.streamingServices.isEmpty)
        #expect(movie.streamingService == nil)
        #expect(movie.legacyStreamingServiceName == nil)
    }

    /// The adoption runs on every open, so it has to be harmless once it has nothing left
    /// to do — that is what lets it get by without remembering whether it has run.
    @Test func openingAgainAfterAnAdoptionRegistersNothingFurther() throws {
        let container = try Library.inMemoryContainer()
        let library = Library(container: container)
        let movie = try library.addTrackedMovie(title: "Okja")
        movie.legacyStreamingServiceName = "Netflix"

        _ = Library(container: container)
        let opened = Library(container: container)

        #expect(opened.streamingServices.map(\.name) == ["Netflix"])
        #expect(movie.streamingService?.name == "Netflix")
    }

    @Test func anAdoptedServiceSurvivesAnAppRelaunch() throws {
        let storeURL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let library = Library(container: try Library.container(at: storeURL))
        let movie = try library.addTrackedMovie(title: "Okja")
        movie.legacyStreamingServiceName = "Netflix"
        // Nothing else here writes to disk, and a store this test opens again is a
        // different container: the name has to be on disk to be a name to adopt.
        library.setWatched(true, on: movie)
        _ = Library(container: try Library.container(at: storeURL))

        let relaunched = Library(container: try Library.container(at: storeURL))

        #expect(relaunched.streamingServices.map(\.name) == ["Netflix"])
        #expect(relaunched.trackedMovies.first?.streamingService?.name == "Netflix")
    }
}

/// Registering a service is a step on the way to most tests about entries, never what
/// they are about, so they take one by name in a single expression.
@MainActor
extension Library {
    func service(_ name: String) throws -> StreamingService {
        try addStreamingService(name: name)
    }
}

/// Stand-ins for the image bytes a Logo holds. Nothing reads them as an image, so what
/// matters is only that they are bytes, and that the two are told apart.
private extension Data {
    static let logo = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])
    static let otherLogo = Data([0x89, 0x50, 0x4E, 0x47])
}
