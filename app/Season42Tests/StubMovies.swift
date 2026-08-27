import Foundation
@testable import Season42

/// The BFF as a movie search sees it, with nothing behind it — one stub for the one protocol
/// searching for a movie asks through, so the series and logo stubs beside it are untouched by
/// anything that happens here.
///
/// Pinned to the main actor, which every caller of it here already is, so a test can read what
/// was asked for and hold an answer back mid-flight without a race of its own.
@MainActor
final class StubMovies: MovieSearching {
    /// What every search answers with, for the tests that run only one.
    var served: [MovieMatch]

    /// What a particular search text answers with, for the tests that run two.
    var answers: [String: [MovieMatch]] = [:]

    /// What every match's details answer with, for the tests that open only one.
    var servedDetails: MovieDetails?

    /// What a particular match's details answer with, for the tests that open two.
    var detailAnswers: [Int: MovieDetails] = [:]

    /// What every match's poster answers with, for the tests that open only one.
    var servedPoster: Data?

    /// What a particular match's poster answers with, for the tests that open two.
    var posterAnswers: [Int: Data] = [:]

    /// Whether the poster ask fails, on its own flag: a poster that won't come is the case
    /// where everything else did, so it is not the same failure as the details'.
    var posterFails = false

    /// Whether every ask fails. One flag for both, because a test is about one or the other.
    var fails: Bool

    /// How it fails, for the tests that are about which failure it was.
    var failure: BffError

    private(set) var searched: [String] = []
    private(set) var opened: [Int] = []
    private(set) var postersAsked: [Int] = []

    private var isHolding = false
    private var held: [String: CheckedContinuation<Void, Never>] = [:]
    private var started: Set<String> = []
    private var watchers: [CheckedContinuation<Void, Never>] = []

    init(
        matches: [MovieMatch] = [],
        details: MovieDetails? = nil,
        poster: Data? = nil,
        fails: Bool = false,
        as failure: BffError = .notServed(status: 502)
    ) {
        self.served = matches
        self.servedDetails = details
        self.servedPoster = poster
        self.fails = fails
        self.failure = failure
    }

    func movies(matching text: String) async throws -> [MovieMatch] {
        searched.append(text)
        await waitIfHeld(at: text)
        if fails { throw failure }
        return answers[text] ?? served
    }

    func movieDetails(for id: Int) async throws -> MovieDetails {
        opened.append(id)
        await waitIfHeld(at: Self.gate(forDetailsOf: id))
        if fails { throw failure }
        guard let details = detailAnswers[id] ?? servedDetails else {
            throw BffError.notServed(status: 404)
        }
        return details
    }

    func moviePoster(for id: Int) async throws -> Data {
        postersAsked.append(id)
        await waitIfHeld(at: Self.gate(forPosterOf: id))
        if fails || posterFails { throw failure }
        guard let poster = posterAnswers[id] ?? servedPoster else {
            throw BffError.notServed(status: 404)
        }
        return poster
    }

    // MARK: - Holding an answer back

    /// Makes every ask from here on wait to be released, so a test can look at one mid-flight
    /// and choose which of two answers lands first.
    func holdAnswers() { isHolding = true }

    /// Returns once a held search for `text` has actually been asked for.
    func searchStarted(_ text: String) async { await waitUntilStarted(text) }

    /// Returns once a held open of the match with `id` has actually been asked for.
    func openStarted(_ id: Int) async { await waitUntilStarted(Self.gate(forDetailsOf: id)) }

    /// Lets the held search for `text` answer.
    func releaseSearch(_ text: String) { release(text) }

    /// Lets the held open of the match with `id` answer.
    func releaseOpen(_ id: Int) { release(Self.gate(forDetailsOf: id)) }

    /// Returns once a held ask for the poster of the match with `id` has actually been made.
    func posterStarted(_ id: Int) async { await waitUntilStarted(Self.gate(forPosterOf: id)) }

    /// Lets the held ask for the poster of the match with `id` answer.
    func releasePoster(_ id: Int) { release(Self.gate(forPosterOf: id)) }

    /// The asks share one gate, so they are told apart by what they are keyed under.
    private static func gate(forDetailsOf id: Int) -> String { "details \(id)" }

    private static func gate(forPosterOf id: Int) -> String { "poster \(id)" }

    private func waitIfHeld(at gate: String) async {
        guard isHolding else { return }
        started.insert(gate)
        wakeWatchers()
        await withCheckedContinuation { held[gate] = $0 }
    }

    private func waitUntilStarted(_ gate: String) async {
        while !started.contains(gate) {
            await withCheckedContinuation { watchers.append($0) }
        }
    }

    private func release(_ gate: String) {
        started.remove(gate)
        held.removeValue(forKey: gate)?.resume()
    }

    private func wakeWatchers() {
        let waiting = watchers
        watchers = []
        for watcher in waiting { watcher.resume() }
    }
}
