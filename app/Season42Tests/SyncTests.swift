import Foundation
import Testing
@testable import Season42

/// Tests Sync: replacing the cached Catalog with what the API serves, and what happens
/// to what was cached when that doesn't work. Everything here runs against a stubbed
/// `CatalogFetching` — the URLSession client is the one layer no stub stands in for.
@MainActor
struct SyncTests {
    // MARK: - A Sync the user asked for

    @Test func aSuccessfulSyncReplacesEverythingCached() async throws {
        let catalog = try Catalog.inMemory()
        try catalog.fill(from: .justTheBear)

        try await catalog.sync(using: StubbedCatalogApi.serving(.justSeverance))

        #expect(catalog.series.map(\.title) == ["Severance"])
        #expect(catalog.movies.map(\.title) == ["Dune: Part Two"])
        #expect(catalog.streamingServices.map(\.name) == ["Apple TV"])
    }

    @Test func aSyncFillsACacheThatHasNothingInItYet() async throws {
        let catalog = try Catalog.inMemory()
        #expect(catalog.isEmpty)

        try await catalog.sync(using: StubbedCatalogApi.serving(.justTheBear))

        #expect(catalog.series.map(\.title) == ["The Bear"])
        #expect(!catalog.isEmpty)
    }

    @Test func aSyncThatServesAnEmptyCatalogEmptiesTheCache() async throws {
        let catalog = try Catalog.inMemory()
        try catalog.fill(from: .justTheBear)

        try await catalog.sync(using: StubbedCatalogApi.serving(.empty))

        #expect(catalog.isEmpty)
    }

    @Test func aFailedSyncLeavesTheCacheAsItWas() async throws {
        let catalog = try Catalog.inMemory()
        try catalog.fill(from: .justTheBear)

        await #expect(throws: StubbedApiFailure.offline) {
            try await catalog.sync(using: StubbedCatalogApi.failing)
        }

        #expect(catalog.series.map(\.title) == ["The Bear"])
        #expect(catalog.movies.map(\.title) == ["Past Lives"])
        #expect(catalog.streamingServices.map(\.name) == ["Netflix"])
    }

    // MARK: - What the tab shows while it happens

    @Test func aSyncIsOverOnceItSucceeds() async throws {
        let catalog = try Catalog.inMemory()
        #expect(!catalog.isSyncing)

        try await catalog.sync(using: StubbedCatalogApi.serving(.justTheBear))

        #expect(!catalog.isSyncing)
    }

    @Test func aSyncIsOverOnceItFails() async throws {
        let catalog = try Catalog.inMemory()

        try? await catalog.sync(using: StubbedCatalogApi.failing)

        #expect(!catalog.isSyncing)
    }

    @Test func theCatalogSaysItIsSyncingWhileTheApiIsAnswering() async throws {
        let catalog = try Catalog.inMemory()
        let seen = SyncObservation()

        try await catalog.sync(
            using: StubbedCatalogApi(serving: .justTheBear) {
                seen.wasSyncing = catalog.isSyncing
            }
        )

        #expect(seen.wasSyncing)
    }

    /// A launch's Sync is not something to watch happen: it says nothing while it runs,
    /// so the Catalog tab keeps its Sync button rather than spinning by itself.
    @Test func aQuietSyncNeverSaysItIsSyncing() async throws {
        let catalog = try Catalog.inMemory()
        let seen = SyncObservation()

        await catalog.syncQuietly(
            using: StubbedCatalogApi(serving: .justTheBear) {
                seen.wasSyncing = catalog.isSyncing
            }
        )

        #expect(!seen.wasSyncing)
        #expect(catalog.series.map(\.title) == ["The Bear"])
    }

    // MARK: - A Sync nobody asked for

    @Test func aQuietSyncReplacesTheCacheWhenTheApiAnswers() async throws {
        let catalog = try Catalog.inMemory()
        try catalog.fill(from: .justTheBear)

        await catalog.syncQuietly(using: StubbedCatalogApi.serving(.justSeverance))

        #expect(catalog.series.map(\.title) == ["Severance"])
    }

    /// What a launch with no API reachable comes to: the cache the user had, and nothing
    /// thrown for anyone to report.
    @Test func aQuietSyncThatFailsKeepsTheCacheAndSaysNothing() async throws {
        let catalog = try Catalog.inMemory()
        try catalog.fill(from: .justTheBear)

        await catalog.syncQuietly(using: StubbedCatalogApi.failing)

        #expect(catalog.series.map(\.title) == ["The Bear"])
        #expect(!catalog.isSyncing)
    }

    @Test func aQuietSyncOnAFirstLaunchLeavesTheBundledSnapshotWhenTheApiIsUnreachable() async throws {
        let catalog = try Catalog.inMemory()
        try catalog.fillFromBundledSnapshotIfEmpty()
        let bundled = catalog.series.map(\.title)

        await catalog.syncQuietly(using: StubbedCatalogApi.failing)

        #expect(catalog.series.map(\.title) == bundled)
    }

    /// A Sync the user asked for reports what went wrong, so everything that can go wrong
    /// has to be sayable — including the two things only the API can be wrong about.
    @Test(arguments: [CatalogError.notServed(status: 503), .notACatalog, .snapshotMissing])
    func everyCatalogFailureSaysSomethingTheUserCanRead(failure: CatalogError) {
        #expect(!(failure.errorDescription ?? "").isEmpty)
        #expect(failure.localizedDescription == failure.errorDescription)
    }

    // MARK: - Sync is not the user's data

    /// The heart of it: the Catalog is shared, read-only data in its own store (ADR-0001),
    /// and a copy the user tracks is theirs from the moment it exists (ADR-0002). So no
    /// outcome of a Sync — served, refused, or served empty — may reach the Library.
    @Test(arguments: SyncOutcome.allCases)
    func noSyncOutcomeTouchesTheLibrary(outcome: SyncOutcome) async throws {
        let library = try Library.inMemory()
        let catalog = try Catalog.inMemory()
        try catalog.fill(from: .justTheBear)
        let bear = try #require(catalog.series.first)
        try library.track(bear, status: .watching)
        try library.addTrackedMovie(title: "Anatomy of a Fall")
        let tracked = library.entries.map(\.title)

        try? await catalog.sync(using: outcome.api)

        #expect(library.entries.map(\.title) == tracked)
        #expect(library.trackedSeries.map(\.title) == ["The Bear"])
        #expect(library.trackedMovies.map(\.title) == ["Anatomy of a Fall"])
    }

    /// A Sync that no longer serves a series the user tracks doesn't take theirs away —
    /// the copy stopped being the Catalog's the moment it was made.
    @Test func aSyncThatDropsASeriesLeavesTheCopyTheUserTracks() async throws {
        let library = try Library.inMemory()
        let catalog = try Catalog.inMemory()
        try catalog.fill(from: .justTheBear)
        try library.track(try #require(catalog.series.first), status: .watching)

        try await catalog.sync(using: StubbedCatalogApi.serving(.empty))

        #expect(catalog.isEmpty)
        #expect(library.trackedSeries.map(\.title) == ["The Bear"])
    }
}

// MARK: - A stubbed API

/// The three ways a Sync can turn out, as far as anything outside the Catalog can tell.
enum SyncOutcome: String, CaseIterable {
    case served
    case servedNothing
    case refused

    var api: StubbedCatalogApi {
        switch self {
        case .served: .serving(.justSeverance)
        case .servedNothing: .serving(.empty)
        case .refused: .failing
        }
    }
}

/// An API that serves whatever the test says, or nothing at all — everything about Sync
/// but the network.
struct StubbedCatalogApi: CatalogFetching {
    private let snapshot: CatalogSnapshot?
    /// Run while the fetch is in flight, so a test can see the Catalog mid-Sync.
    private let whileFetching: @Sendable @MainActor () -> Void

    init(
        serving snapshot: CatalogSnapshot?,
        whileFetching: @escaping @Sendable @MainActor () -> Void = {}
    ) {
        self.snapshot = snapshot
        self.whileFetching = whileFetching
    }

    /// An API that answers with this Catalog.
    static func serving(_ snapshot: CatalogSnapshot) -> Self { Self(serving: snapshot) }

    /// An API that can't be reached — the ordinary case of a launch with no network.
    static let failing = Self(serving: nil)

    func fetchSnapshot() async throws -> CatalogSnapshot {
        await whileFetching()
        guard let snapshot else { throw StubbedApiFailure.offline }
        return snapshot
    }
}

/// What a test saw of the Catalog while a Sync was still in flight.
@MainActor final class SyncObservation {
    var wasSyncing = false
}

enum StubbedApiFailure: Error, Equatable {
    case offline
}
