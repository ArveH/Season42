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
        @NullWhenUnset var logo: Data?
    }

    struct Series: Encodable {
        let title: String
        let description: String
        @NullWhenUnset var poster: Data?
        /// One episode count per season, in season order.
        let seasons: [Int]
        let status: WatchStatus
        @NullWhenUnset var position: Position?
        /// The name of the Streaming Service it names, one of `streamingServices`.
        @NullWhenUnset var streamingService: String?
        @NullWhenUnset var nextEpisodeDate: Date?
        @NullWhenUnset var releaseSlot: Slot?
        let addedAt: Date
        /// Watched At (ADR-0014).
        @NullWhenUnset var watchedAt: Date?

        /// A Release Slot as its two stored parts, without the `hour` and `minute` a
        /// form reads it as.
        struct Slot: Encodable {
            let weekday: Int
            let minutesPastMidnight: Int
        }
    }

    struct Movie: Encodable {
        let title: String
        let description: String
        @NullWhenUnset var poster: Data?
        /// The name of the Streaming Service it names, one of `streamingServices`.
        @NullWhenUnset var streamingService: String?
        let addedAt: Date
        let isWatched: Bool
        /// When the user last marked it watched, which an un-mark leaves in place.
        @NullWhenUnset var watchedAt: Date?
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

/// An optional field of the Library Export, written as `null` when unset: a synthesized
/// `Encodable` leaves an unset optional out, and the Export names every field in every entry.
@propertyWrapper
struct NullWhenUnset<Value: Encodable>: Encodable {
    var wrappedValue: Value?

    init(wrappedValue: Value?) {
        self.wrappedValue = wrappedValue
    }

    func encode(to encoder: any Encoder) throws {
        var field = encoder.singleValueContainer()
        if let wrappedValue {
            try field.encode(wrappedValue)
        } else {
            try field.encodeNil()
        }
    }
}
