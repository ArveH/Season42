import Foundation
import Testing
@testable import Season42

/// Tests the Poster where it is kept: on the Tracked Movie itself, as bytes. Bytes and not a
/// link, so a movie adopted once goes on drawing with the BFF stopped, unreachable or never
/// deployed — which is what these assert by never having one at all.
@MainActor
struct TrackedMoviePosterTests {
    private let poster = Data("a poster".utf8)
    private let another = Data("another poster".utf8)

    @Test func aMovieAddedWithAPosterKeepsTheBytes() throws {
        let library = try Library.inMemory()

        let movie = try library.addTrackedMovie(title: "Arrival", poster: poster)

        #expect(movie.poster == poster)
    }

    /// Every movie entered by hand, which is every one until a copy brings a picture.
    @Test func aMovieAddedWithoutOneHasNoPoster() throws {
        let library = try Library.inMemory()

        let movie = try library.addTrackedMovie(title: "Arrival")

        #expect(movie.poster == nil)
    }

    /// An edit rewrites the movie whole, so a Poster left out of one is cleared — which is
    /// what Remove on the form is.
    @Test func anEditWithNoPosterClearsTheOneTheMovieHad() throws {
        let library = try Library.inMemory()
        let movie = try library.addTrackedMovie(title: "Arrival", poster: poster)

        try library.updateTrackedMovie(
            movie,
            title: "Arrival",
            summary: "",
            poster: nil,
            streamingService: nil,
            isWatched: false
        )

        #expect(movie.poster == nil)
    }

    @Test func anEditCanPutADifferentPosterOnTheMovie() throws {
        let library = try Library.inMemory()
        let movie = try library.addTrackedMovie(title: "Arrival", poster: poster)

        try library.updateTrackedMovie(
            movie,
            title: "Arrival",
            summary: "",
            poster: another,
            streamingService: nil,
            isWatched: false
        )

        #expect(movie.poster == another)
    }

    /// The whole point of keeping bytes rather than an id: what was adopted is in the store,
    /// and nothing has to be asked for it again (ADR-0013).
    @Test func anAdoptedPosterSurvivesAnAppRelaunch() throws {
        let storeURL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let library = Library(container: try Library.container(at: storeURL))
        try library.addTrackedMovie(title: "Arrival", poster: poster)

        let relaunched = Library(container: try Library.container(at: storeURL))

        #expect(relaunched.trackedMovies.first?.poster == poster)
    }
}
