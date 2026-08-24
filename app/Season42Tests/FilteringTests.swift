import Foundation
import Testing
@testable import Season42

/// Tests the Library Filter: how a search text, a Status and a kind narrow the Library
/// listing, alone and together. The narrowing lives in the `Library` facade, so that is
/// where it is tested; the Library tab only holds the filter the user has set.
@MainActor
struct FilteringTests {
    // MARK: - Searching by title

    @Test func anEmptyFilterListsEverythingNewestFirst() throws {
        let library = try stocked()

        #expect(library.entries(matching: LibraryFilter()).map(\.title) == everything)
    }

    @Test func aSearchKeepsOnlyTitlesContainingIt() throws {
        let library = try stocked()

        #expect(library.entries(matching: LibraryFilter(searchText: "ver")).map(\.title) == ["Severance"])
    }

    @Test func aSearchIgnoresCase() throws {
        let library = try stocked()

        #expect(library.entries(matching: LibraryFilter(searchText: "aNdOr")).map(\.title) == ["Andor"])
    }

    @Test func aSearchIgnoresAccents() throws {
        let library = try Library.inMemory()
        try library.addTrackedMovie(title: "Amélie")

        #expect(library.entries(matching: LibraryFilter(searchText: "amelie")).map(\.title) == ["Amélie"])
    }

    @Test func aSearchOfOnlyWhitespaceNarrowsNothing() throws {
        let library = try stocked()

        #expect(library.entries(matching: LibraryFilter(searchText: "   ")).map(\.title) == everything)
    }

    @Test func aSearchMatchingNothingLeavesAnEmptyListing() throws {
        let library = try stocked()

        #expect(library.entries(matching: LibraryFilter(searchText: "Fringe")).isEmpty)
    }

    @Test func aSearchSpansSeriesAndMovies() throws {
        let library = try stocked()

        #expect(
            library.entries(matching: LibraryFilter(searchText: "r")).map(\.title)
                == ["Andor", "Arrival", "Severance"]
        )
    }

    // MARK: - Filtering by kind

    @Test func theKindFilterKeepsOnlySeriesOrOnlyMovies() throws {
        let library = try stocked()

        #expect(library.entries(matching: LibraryFilter(kind: .series)).map(\.title) == ["Andor", "Severance"])
        #expect(library.entries(matching: LibraryFilter(kind: .movie)).map(\.title) == ["Dune", "Arrival"])
    }

    // MARK: - Filtering by Status

    @Test func theStatusFilterKeepsOnlySeriesInThatStatus() throws {
        let library = try stocked()

        #expect(library.entries(matching: LibraryFilter(status: .planned)).map(\.title) == ["Andor"])
        #expect(library.entries(matching: LibraryFilter(status: .watching)).map(\.title) == ["Severance"])
    }

    /// A Tracked Movie has no Status at all — watched or not is the only state it carries —
    /// so asking for one narrows the listing to series.
    @Test func aStatusFilterLeavesNoMoviesInTheListing() throws {
        let library = try stocked()

        for status in WatchStatus.allCases {
            let titles = library.entries(matching: LibraryFilter(status: status)).map(\.title)
            #expect(!titles.contains("Arrival"))
            #expect(!titles.contains("Dune"))
        }
    }

    // MARK: - Combining them

    @Test func aSearchAndTheFiltersNarrowTogether() throws {
        let library = try stocked()
        try library.addTrackedMovie(title: "Andor: The Movie")

        let filter = LibraryFilter(searchText: "andor", status: nil, kind: .series)

        #expect(library.entries(matching: filter).map(\.title) == ["Andor"])
    }

    @Test func aStatusAndAKindThatCannotBothHoldLeaveAnEmptyListing() throws {
        let library = try stocked()

        let filter = LibraryFilter(status: .watching, kind: .movie)

        #expect(library.entries(matching: filter).isEmpty)
    }

    // MARK: - Fixtures

    /// Two series and two movies, added in this order, so the newest-first listing reads
    /// as `everything` below.
    private func stocked() throws -> Library {
        var clock = Date(timeIntervalSince1970: 1_700_000_000)
        let library = try Library.inMemory(now: { clock })
        let tick = { clock = clock.addingTimeInterval(60) }

        try library.addTrackedSeries(title: "Severance", seasons: [9, 10], status: .watching)
        tick()
        try library.addTrackedMovie(title: "Arrival")
        tick()
        try library.addTrackedMovie(title: "Dune")
        tick()
        try library.addTrackedSeries(title: "Andor", seasons: [12], status: .planned)
        return library
    }

    private let everything = ["Andor", "Dune", "Arrival", "Severance"]
}
