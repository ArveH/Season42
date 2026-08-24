/// The season and episode of a Tracked Series the user has most recently watched.
/// A Tracked Series with no Position has had nothing watched yet.
struct Position: Codable, Hashable, Sendable {
    var season: Int
    var episode: Int

    /// e.g. "S2E5" — the shorthand used throughout the UI.
    var shorthand: String {
        "S\(season)E\(episode)"
    }
}
