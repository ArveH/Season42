/// The seasons of a Tracked Series, as one episode count per season in season order.
/// Seasons are numbered from 1, and this type is the only place that arithmetic lives —
/// nothing else should index the underlying counts.
struct Seasons: Codable, Hashable, Sendable, ExpressibleByArrayLiteral {
    private(set) var episodeCounts: [Int]

    init(episodeCounts: [Int]) {
        self.episodeCounts = episodeCounts
    }

    init(arrayLiteral episodeCounts: Int...) {
        self.init(episodeCounts: episodeCounts)
    }

    var count: Int { episodeCounts.count }
    var isEmpty: Bool { episodeCounts.isEmpty }

    /// The episode count of `season`, or nil if there is no such season.
    func episodeCount(inSeason season: Int) -> Int? {
        episodeCounts.indices.contains(season - 1) ? episodeCounts[season - 1] : nil
    }

    /// The first season declared with no episodes, if any. Numbered from 1.
    var firstSeasonWithoutEpisodes: Int? {
        episodeCounts.firstIndex { $0 < 1 }.map { $0 + 1 }
    }

    /// Whether `position` names an episode these seasons actually have.
    func contains(_ position: Position) -> Bool {
        guard let episodes = episodeCount(inSeason: position.season) else { return false }
        return position.episode >= 1 && position.episode <= episodes
    }

    /// The nearest Position these seasons do contain — used while the user is still
    /// editing season and episode counts underneath a Position they already picked.
    func clamping(_ position: Position) -> Position {
        guard !isEmpty else { return position }
        let season = min(max(position.season, 1), count)
        let episodes = episodeCount(inSeason: season) ?? 1
        return Position(season: season, episode: min(max(position.episode, 1), episodes))
    }

    /// Grows or shrinks to `newCount` seasons, keeping the counts already entered.
    /// A newly added season starts out the same length as the one before it.
    mutating func setCount(_ newCount: Int) {
        guard newCount >= 0 else { return }
        while episodeCounts.count < newCount {
            episodeCounts.append(episodeCounts.last ?? 10)
        }
        episodeCounts.removeLast(max(0, episodeCounts.count - newCount))
    }

    /// The episode count of `season`, numbered from 1.
    subscript(season: Int) -> Int {
        get { episodeCount(inSeason: season) ?? 0 }
        set {
            guard episodeCounts.indices.contains(season - 1) else { return }
            episodeCounts[season - 1] = newValue
        }
    }
}
