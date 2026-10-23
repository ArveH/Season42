import Foundation

/// The Library Export: the whole Library written out as one JSON file the user keeps — their
/// own copy, independent of iCloud and of the app being able to open its store (ADR-0023).
/// Nothing reads it back; it is written to be read by a person or another program, so it
/// says things in the Library's own terms rather than the store's, and every field is named
/// in every entry — `null` where it is unset, never left out.
///
/// Posters and Logos are base64 — `JSONEncoder`'s default for `Data` — and dates are
/// ISO 8601, so the file stands alone.
struct LibraryExport: Encodable {
    /// Which shape of file this is, so a reader years from now can tell.
    let version = 1
    let streamingServices: [Service]
    let trackedSeries: [Series]
    let trackedMovies: [Movie]

    /// A Streaming Service, written once. Names are unique (ADR-0006), so an entry names
    /// its service by name and the file reads the way the app does.
    struct Service: Encodable {
        let name: String
        let logo: Data?

        enum CodingKeys: CodingKey { case name, logo }

        func encode(to encoder: any Encoder) throws {
            var fields = encoder.container(keyedBy: CodingKeys.self)
            try fields.encode(name, forKey: .name)
            try fields.encode(logo, forKey: .logo)
        }
    }

    struct Series: Encodable {
        let title: String
        let description: String
        let poster: Data?
        /// One episode count per season, in season order.
        let seasons: [Int]
        let status: WatchStatus
        let position: Position?
        /// The name of the Streaming Service it names, one of `streamingServices`.
        let streamingService: String?
        let nextEpisodeDate: Date?
        let releaseSlot: Slot?
        let addedAt: Date
        /// Watched At (ADR-0014).
        let watchedAt: Date?

        /// A Release Slot as its two stored parts, without the `hour` and `minute` a
        /// form reads it as.
        struct Slot: Encodable {
            let weekday: Int
            let minutesPastMidnight: Int
        }

        enum CodingKeys: CodingKey {
            case title, description, poster, seasons, status, position, streamingService
            case nextEpisodeDate, releaseSlot, addedAt, watchedAt
        }

        func encode(to encoder: any Encoder) throws {
            var fields = encoder.container(keyedBy: CodingKeys.self)
            try fields.encode(title, forKey: .title)
            try fields.encode(description, forKey: .description)
            try fields.encode(poster, forKey: .poster)
            try fields.encode(seasons, forKey: .seasons)
            try fields.encode(status, forKey: .status)
            try fields.encode(position, forKey: .position)
            try fields.encode(streamingService, forKey: .streamingService)
            try fields.encode(nextEpisodeDate, forKey: .nextEpisodeDate)
            try fields.encode(releaseSlot, forKey: .releaseSlot)
            try fields.encode(addedAt, forKey: .addedAt)
            try fields.encode(watchedAt, forKey: .watchedAt)
        }
    }

    struct Movie: Encodable {
        let title: String
        let description: String
        let poster: Data?
        /// The name of the Streaming Service it names, one of `streamingServices`.
        let streamingService: String?
        let addedAt: Date
        let isWatched: Bool
        /// When the user last marked it watched, which an un-mark leaves in place.
        let watchedAt: Date?

        enum CodingKeys: CodingKey {
            case title, description, poster, streamingService, addedAt, isWatched, watchedAt
        }

        func encode(to encoder: any Encoder) throws {
            var fields = encoder.container(keyedBy: CodingKeys.self)
            try fields.encode(title, forKey: .title)
            try fields.encode(description, forKey: .description)
            try fields.encode(poster, forKey: .poster)
            try fields.encode(streamingService, forKey: .streamingService)
            try fields.encode(addedAt, forKey: .addedAt)
            try fields.encode(isWatched, forKey: .isWatched)
            try fields.encode(watchedAt, forKey: .watchedAt)
        }
    }
}

extension LibraryExport.Series {
    init(_ series: TrackedSeries) {
        self.init(
            title: series.title,
            description: series.summary,
            poster: series.poster,
            seasons: series.seasons.seasonNumbers.map { series.seasons[$0] },
            status: series.status,
            position: series.position,
            streamingService: series.streamingService?.name,
            nextEpisodeDate: series.nextEpisodeDate,
            releaseSlot: series.releaseSlot.map {
                Slot(weekday: $0.weekday, minutesPastMidnight: $0.minutesPastMidnight)
            },
            addedAt: series.addedAt,
            watchedAt: series.lastWatchedAt
        )
    }
}

extension LibraryExport.Movie {
    init(_ movie: TrackedMovie) {
        self.init(
            title: movie.title,
            description: movie.summary,
            poster: movie.poster,
            streamingService: movie.streamingService?.name,
            addedAt: movie.addedAt,
            isWatched: movie.isWatched,
            watchedAt: movie.watchedAt
        )
    }
}

extension Library {
    /// The whole Library as a Library Export file: every Streaming Service once, then every
    /// Tracked Series and Tracked Movie naming the service it is on.
    func export() throws -> Data {
        let export = LibraryExport(
            streamingServices: streamingServices.map { .init(name: $0.name, logo: $0.logo) },
            trackedSeries: trackedSeries.map(LibraryExport.Series.init),
            trackedMovies: trackedMovies.map(LibraryExport.Movie.init)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }
}
