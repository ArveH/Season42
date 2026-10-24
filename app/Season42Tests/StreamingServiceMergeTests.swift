import Foundation
import Testing
@testable import Season42

/// Merging one Streaming Service into another: how the user fixes the duplicates an iCloud
/// sync brings in, since nothing merges them on its own (ADR-0025).
@MainActor
struct StreamingServiceMergeTests {
    @Test func everyEntryOnTheMergedServiceMovesToTheTarget() throws {
        let library = try Library.inMemory()
        let merged = try library.service("Netflix")
        let target = try library.service("Netflix Norge")
        try library.addTrackedSeries(
            title: "Dark", seasons: [10], status: .finished, streamingService: merged
        )
        try library.addTrackedSeries(
            title: "Ozark", seasons: [10], status: .watching, streamingService: merged
        )
        try library.addTrackedSeries(
            title: "Lupin", seasons: [5], status: .watching, streamingService: target
        )

        library.mergeStreamingService(merged, into: target)

        #expect(library.streamingServices.map(\.name) == ["Netflix Norge"])
        #expect(library.entryCount(of: target) == 3)
    }

    @Test func trackedMoviesMoveAsWellAsTrackedSeries() throws {
        let library = try Library.inMemory()
        let merged = try library.service("Netflix")
        let target = try library.service("Netflix Norge")
        let series = try library.addTrackedSeries(
            title: "Dark", seasons: [10], status: .finished, streamingService: merged
        )
        let movie = try library.addTrackedMovie(title: "Roma", streamingService: merged).entry

        library.mergeStreamingService(merged, into: target)

        #expect(series.streamingService?.name == "Netflix Norge")
        #expect(movie.streamingService?.name == "Netflix Norge")
        #expect(library.entryCount(of: target) == 2)
    }

    // MARK: - The Logo and the name

    @Test func aTargetWithNoLogoTakesTheMergedServicesLogo() throws {
        let library = try Library.inMemory()
        let merged = try library.addStreamingService(name: "Netflix", logo: .logo)
        let target = try library.service("Netflix Norge")

        library.mergeStreamingService(merged, into: target)

        #expect(target.logo == .logo)
    }

    @Test func aTargetWithALogoKeepsItsOwn() throws {
        let library = try Library.inMemory()
        let merged = try library.addStreamingService(name: "Netflix", logo: .logo)
        let target = try library.addStreamingService(name: "Netflix Norge", logo: .otherLogo)

        library.mergeStreamingService(merged, into: target)

        #expect(target.logo == .otherLogo)
    }

    @Test func theTargetKeepsItsOwnName() throws {
        let library = try Library.inMemory()
        let merged = try library.service("Netflix")
        let target = try library.service("Netflix Norge")

        library.mergeStreamingService(merged, into: target)

        #expect(target.name == "Netflix Norge")
    }

    // MARK: - Nothing to move

    @Test func mergingAServiceNothingNamesDeletesItAndMovesNothing() throws {
        let library = try Library.inMemory()
        let merged = try library.service("Netflix")
        let target = try library.service("Netflix Norge")
        let other = try library.service("NRK TV")
        let series = try library.addTrackedSeries(
            title: "Skam", seasons: [10], status: .finished, streamingService: other
        )

        library.mergeStreamingService(merged, into: target)

        #expect(library.streamingServices.map(\.name) == ["Netflix Norge", "NRK TV"])
        #expect(library.entryCount(of: target) == 0)
        #expect(series.streamingService?.name == "NRK TV")
    }

    @Test func mergingAServiceIntoItselfChangesNothing() throws {
        let library = try Library.inMemory()
        let service = try library.service("Netflix")
        try library.addTrackedSeries(
            title: "Dark", seasons: [10], status: .finished, streamingService: service
        )

        library.mergeStreamingService(service, into: service)

        #expect(library.streamingServices.map(\.name) == ["Netflix"])
        #expect(library.entryCount(of: service) == 1)
    }

    /// The tab draws the target's count straight after the merge, with no relaunch: its
    /// reader has to be told, as for any other change to a count (ADR-0018).
    @Test func aMergeTellsAReaderOfTheTargetsCount() throws {
        let library = try Library.inMemory()
        let merged = try library.service("Netflix")
        let target = try library.service("Netflix Norge")
        try library.addTrackedMovie(title: "Roma", streamingService: merged)
        let probe = ObservationProbe()

        withObservationTracking {
            _ = library.entryCount(of: target)
        } onChange: {
            probe.tell()
        }
        library.mergeStreamingService(merged, into: target)

        #expect(probe.wasTold)
    }

    // MARK: - What the naming sheet offers

    /// Every other service, in the tab's order, and not only those with a similar name:
    /// "TV 2 Play" and "TV2 Play" are not the same name, but are the user's to merge.
    @Test func renamingASheetOffersEveryOtherServiceInTheTabsOrder() throws {
        let library = try Library.inMemory()
        try library.service("TV2 Play")
        let renaming = try library.service("TV 2 Play")
        try library.service("Apple TV+")

        let targets = ServiceNaming.renaming(renaming).mergeTargets(in: library.streamingServices)

        #expect(targets.map(\.name) == ["Apple TV+", "TV2 Play"])
    }

    @Test func theOnlyServiceHasNothingToMergeInto() throws {
        let library = try Library.inMemory()
        let only = try library.service("Netflix")

        #expect(ServiceNaming.renaming(only).mergeTargets(in: library.streamingServices).isEmpty)
    }

    @Test func aServiceBeingAddedHasNothingToMergeInto() throws {
        let library = try Library.inMemory()
        try library.service("Netflix")

        #expect(ServiceNaming.adding.mergeTargets(in: library.streamingServices).isEmpty)
    }
}
