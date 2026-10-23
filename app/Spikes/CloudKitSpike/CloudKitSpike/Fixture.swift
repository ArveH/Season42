// PROTOTYPE — the CloudKit spike for #137. Throwaway; never merged to main.
//
// Test data only, the same on every device and every launch, so a device that only ever
// imported from CloudKit can check what it received against what was seeded elsewhere.
// One series per Status, and every optional value both set and unset somewhere.

import Foundation
import SwiftData

enum Fixture {
    struct Series {
        let title: String
        let posterSize: Int?
        let seasons: Seasons
        let status: WatchStatus
        let position: Position?
        let service: String?
        let nextEpisodeDate: Date?
        let releaseSlot: ReleaseSlot?
        let lastWatchedAt: Date?
    }

    struct Movie {
        let title: String
        let posterSize: Int?
        let service: String?
        let isWatched: Bool
        let watchedAt: Date?
    }

    /// A fixed moment, so dates compare exactly across devices.
    static func day(_ n: Double) -> Date { Date(timeIntervalSince1970: 1_790_000_000 + n * 86_400) }

    /// Names and Logo sizes. The large one is over the size SwiftData moves to external
    /// storage, the small one under it, so both paths are seen.
    static let services: [(name: String, logoSize: Int?)] = [
        ("Spike Flix", 4_000),
        ("Spike Box", 250_000),
        ("Spike Nothing", nil),
    ]

    static let series: [Series] = [
        Series(title: "Alpha Watching", posterSize: 300_000, seasons: [10, 8, 12], status: .watching,
               position: Position(season: 2, episode: 5), service: "Spike Flix",
               nextEpisodeDate: day(3), releaseSlot: ReleaseSlot(weekday: 3, hour: 21, minute: 0),
               lastWatchedAt: day(-1)),
        Series(title: "Bravo Waiting", posterSize: nil, seasons: [6], status: .waiting,
               position: Position(season: 1, episode: 6), service: "Spike Box",
               nextEpisodeDate: day(40), releaseSlot: nil, lastWatchedAt: day(-30)),
        Series(title: "Charlie Planned", posterSize: 2_000, seasons: [1], status: .planned,
               position: nil, service: nil, nextEpisodeDate: nil, releaseSlot: nil,
               lastWatchedAt: nil),
        Series(title: "Delta Finished", posterSize: 150_000, seasons: [3, 3], status: .finished,
               position: Position(season: 2, episode: 3), service: "Spike Flix",
               nextEpisodeDate: nil, releaseSlot: ReleaseSlot(weekday: 7, minutesPastMidnight: 0),
               lastWatchedAt: day(-200)),
        Series(title: "Echo Dropped", posterSize: nil, seasons: [22, 22, 22, 22, 22, 22, 22], status: .dropped,
               position: Position(season: 4, episode: 1), service: "Spike Box",
               nextEpisodeDate: nil, releaseSlot: ReleaseSlot(weekday: 1, hour: 23, minute: 59),
               lastWatchedAt: day(-400)),
    ]

    static let movies: [Movie] = [
        Movie(title: "Foxtrot Movie", posterSize: 200_000, service: "Spike Flix", isWatched: true, watchedAt: day(-5)),
        Movie(title: "Golf Movie", posterSize: nil, service: nil, isWatched: false, watchedAt: day(-90)),
    ]

    /// Bytes that look like an image to nobody but are the same everywhere: a seeded
    /// generator, keyed by size so two Posters of different sizes differ.
    static func bytes(_ count: Int) -> Data {
        var state = UInt64(count) &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        var data = Data(capacity: count)
        for _ in 0..<count {
            state = state &* 6_364_136_223_846_793_005 &+ 1
            data.append(UInt8(truncatingIfNeeded: state >> 33))
        }
        return data
    }

    static func seed(into context: ModelContext) throws {
        var byName: [String: StreamingService] = [:]
        for service in services {
            let model = StreamingService(name: service.name, logo: service.logoSize.map(bytes))
            context.insert(model)
            byName[service.name] = model
        }
        for (index, s) in series.enumerated() {
            context.insert(TrackedSeries(
                title: s.title, summary: "Summary of \(s.title)", poster: s.posterSize.map(bytes),
                seasons: s.seasons, status: s.status, position: s.position,
                streamingService: s.service.flatMap { byName[$0] }, nextEpisodeDate: s.nextEpisodeDate,
                releaseSlot: s.releaseSlot, addedAt: day(Double(-index)), lastWatchedAt: s.lastWatchedAt))
        }
        for (index, m) in movies.enumerated() {
            context.insert(TrackedMovie(
                title: m.title, summary: "Summary of \(m.title)", poster: m.posterSize.map(bytes),
                streamingService: m.service.flatMap { byName[$0] }, addedAt: day(Double(-10 - index)),
                isWatched: m.isWatched, watchedAt: m.watchedAt))
        }
        try context.save()
    }

    /// Every way the store differs from the fixture, as lines a person can read. Empty means
    /// every value and every link came through.
    static func differences(in context: ModelContext) throws -> [String] {
        var out: [String] = []
        func check<T: Equatable>(_ what: String, _ got: T, _ want: T) {
            if got != want { out.append("✗ \(what): got \(got), want \(want)") }
        }

        let storedServices = try context.fetch(FetchDescriptor<StreamingService>())
        check("service count", storedServices.count, services.count)
        for want in services {
            guard let got = storedServices.first(where: { $0.name == want.name }) else {
                out.append("✗ service \(want.name) missing"); continue
            }
            check("\(want.name).logo", got.logo, want.logoSize.map(bytes))
            let wantSeries = Set(series.filter { $0.service == want.name }.map(\.title))
            check("\(want.name).series", Set((got.series ?? []).map(\.title)), wantSeries)
            let wantMovies = Set(movies.filter { $0.service == want.name }.map(\.title))
            check("\(want.name).movies", Set((got.movies ?? []).map(\.title)), wantMovies)
        }

        let storedSeries = try context.fetch(FetchDescriptor<TrackedSeries>())
        check("series count", storedSeries.count, series.count)
        for (index, want) in series.enumerated() {
            guard let got = storedSeries.first(where: { $0.title == want.title }) else {
                out.append("✗ series \(want.title) missing"); continue
            }
            let t = want.title
            check("\(t).summary", got.summary, "Summary of \(t)")
            check("\(t).poster", got.poster, want.posterSize.map(bytes))
            check("\(t).seasons", got.seasons, want.seasons)
            check("\(t).status", got.status, want.status)
            check("\(t).position", got.position, want.position)
            check("\(t).service", got.streamingService?.name, want.service)
            check("\(t).nextEpisodeDate", got.nextEpisodeDate, want.nextEpisodeDate)
            check("\(t).releaseSlot", got.releaseSlot, want.releaseSlot)
            check("\(t).addedAt", got.addedAt, day(Double(-index)))
            check("\(t).lastWatchedAt", got.lastWatchedAt, want.lastWatchedAt)
        }

        let storedMovies = try context.fetch(FetchDescriptor<TrackedMovie>())
        check("movie count", storedMovies.count, movies.count)
        for (index, want) in movies.enumerated() {
            guard let got = storedMovies.first(where: { $0.title == want.title }) else {
                out.append("✗ movie \(want.title) missing"); continue
            }
            let t = want.title
            check("\(t).summary", got.summary, "Summary of \(t)")
            check("\(t).poster", got.poster, want.posterSize.map(bytes))
            check("\(t).service", got.streamingService?.name, want.service)
            check("\(t).addedAt", got.addedAt, day(Double(-10 - index)))
            check("\(t).isWatched", got.isWatched, want.isWatched)
            check("\(t).watchedAt", got.watchedAt, want.watchedAt)
        }
        return out
    }
}
