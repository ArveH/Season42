import Foundation

/// The Catalog exactly as it is served: the whole shared pool of streaming services,
/// series and movies as one document. It is what `GET /catalog` returns and, byte for
/// byte, what the app bundles as its first-launch snapshot (ADR-0003), so this is the
/// one place the wire shape is spelled out. Decoded, never stored — filling the on-device
/// Catalog cache from it is `Catalog`'s job.
struct CatalogSnapshot: Equatable, Sendable, Codable {
    var streamingServices: [CatalogStreamingServiceSnapshot]
    var series: [CatalogSeriesSnapshot]
    var movies: [CatalogMovieSnapshot]
}

/// A streaming service as the Catalog serves it. The user's own `streamingService` on a
/// Tracked Series or Tracked Movie is free text, so nothing here constrains what they
/// may type — these are the services the app can offer them.
struct CatalogStreamingServiceSnapshot: Equatable, Sendable, Codable {
    var externalId: String
    var name: String
}

/// A series in the Catalog: a template, not a link. Tracking it copies these fields into
/// the user's own data, which is thereafter independent (ADR-0002).
struct CatalogSeriesSnapshot: Equatable, Sendable {
    /// The id the Catalog's data source knows this series by — a TMDB id for the series
    /// the shipped snapshot carries.
    var externalId: String
    var title: String
    /// What the series is about. Served as `description`, carried here as `summary`,
    /// exactly as a Tracked Series carries the user's own note.
    var summary: String
    var posterUrl: String?
    var seasons: Seasons
}

/// A movie in the Catalog, on the same template terms as a series but without seasons.
struct CatalogMovieSnapshot: Equatable, Sendable {
    var externalId: String
    var title: String
    var summary: String
    var posterUrl: String?
}

// MARK: - Decoding

extension CatalogSnapshot {
    /// Decodes a served or bundled Catalog document.
    ///
    /// - Throws: a `DecodingError` if the JSON isn't a Catalog; a half-read snapshot is
    ///   worse than none, so nothing partial comes back.
    init(json: Data) throws {
        self = try JSONDecoder().decode(CatalogSnapshot.self, from: json)
    }

    /// The snapshot the app ships with: the Catalog as it stood when this build was cut,
    /// and the only source of one until the app can fetch a Catalog.
    ///
    /// - Throws: `CatalogError.snapshotMissing` if the resource isn't in the bundle,
    ///   or a `DecodingError` if it isn't a Catalog.
    static func bundled() throws -> CatalogSnapshot {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json") else {
            throw CatalogError.snapshotMissing
        }
        return try CatalogSnapshot(json: try Data(contentsOf: url))
    }
}

// The two coding conformances below are hand-written for one reason each, and both live
// in extensions so the memberwise initializers survive: `description` is the served name
// of what the app calls `summary`, and seasons are served as a flat array of episode
// counts rather than as `Seasons` encodes itself for storage.
extension CatalogSeriesSnapshot: Codable {
    private enum CodingKeys: String, CodingKey {
        case externalId, title, posterUrl
        case summary = "description"
        case seasons
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        externalId = try container.decode(String.self, forKey: .externalId)
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decode(String.self, forKey: .summary)
        posterUrl = try container.decodeIfPresent(String.self, forKey: .posterUrl)
        seasons = Seasons(episodeCounts: try container.decode([Int].self, forKey: .seasons))

        // A series with no seasons, or a season with no episodes, is what the Library
        // refuses to store by hand — so it is not something the Catalog may serve either.
        // Caching it would leave the tab showing a series it can say nothing about.
        guard !seasons.isEmpty, seasons.firstSeasonWithoutEpisodes == nil else {
            throw DecodingError.dataCorruptedError(
                forKey: .seasons,
                in: container,
                debugDescription: "Every season of \(title) needs at least one episode."
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(externalId, forKey: .externalId)
        try container.encode(title, forKey: .title)
        try container.encode(summary, forKey: .summary)
        try container.encode(posterUrl, forKey: .posterUrl)
        try container.encode(seasons.episodeCounts, forKey: .seasons)
    }
}

extension CatalogMovieSnapshot: Codable {
    private enum CodingKeys: String, CodingKey {
        case externalId, title, posterUrl
        case summary = "description"
    }
}
