import Foundation
@testable import Season42

extension CatalogSnapshot {
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

    /// A second snapshot that shares nothing with `justTheBear`, for telling a replaced
    /// Catalog apart from the one that was cached before it.
    static let justSeverance = CatalogSnapshot(
        streamingServices: [
            CatalogStreamingServiceSnapshot(externalId: "appletv", name: "Apple TV")
        ],
        series: [
            CatalogSeriesSnapshot(
                externalId: "95396",
                title: "Severance",
                summary: "Mark leads a team whose memories are surgically divided.",
                posterUrl: nil,
                seasons: [9]
            )
        ],
        movies: [
            CatalogMovieSnapshot(
                externalId: "1160419",
                title: "Dune: Part Two",
                summary: "Paul unites with the Fremen.",
                posterUrl: nil
            )
        ]
    )
}
