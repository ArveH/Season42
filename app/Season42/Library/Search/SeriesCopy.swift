import Foundation

/// What Copy would write into the form, worked out before it is tapped: a Title, a Description
/// and the seasons the app can hold, together with every note the user is owed about how they
/// were arrived at.
///
/// A value rather than something the detail screen does, because every rule about copying lives
/// in here — which seasons survive, which are invented, where the Position lands — and a rule in
/// a value is a rule with a test. The screen renders this and decides nothing.
///
/// It carries only what TMDB's answer speaks to. Status, Streaming Service, Next Episode Date
/// and the watched state are the user's alone and nothing in a Series Details has a word to say
/// about them, so nothing here holds them.
struct SeriesCopy: Equatable, Sendable {
    /// The series' name, as TMDB has it — and the user's own the moment it lands in the form.
    let title: String

    /// What the series is about, in TMDB's words. The Description, theirs to edit from there,
    /// and never a link back to where it came from (ADR-0002).
    let summary: String

    /// TMDB's seasons flattened into what the app can hold: the specials gone, the seasons with
    /// no episodes gone, and whatever gap that leaves filled so TMDB's numbering survives
    /// (ADR-0011).
    let seasons: Seasons

    /// Everything this copy would do that TMDB's answer does not itself say — what was dropped,
    /// what was invented, and where the Position would end up. Said on the detail screen before
    /// Copy is tapped, which is the whole of what makes the inventing honest. Empty where the
    /// answer needed nothing done to it.
    let notes: [SeriesCopyNote]

    /// Whether copying would take something the user has already put in the form, which is what
    /// makes Copy ask before it writes.
    let overwritesTheForm: Bool

    /// Where the Position would land, where the copied seasons no longer reach the one the form
    /// holds, and nil where it would not move at all. Said on the detail screen before Copy and
    /// again on the form after it, because a Position that moved while the user was looking at
    /// another screen is a Position they never saw move.
    var movedPosition: Position? {
        for note in notes {
            if case .movesPosition(_, let to) = note { return to }
        }
        return nil
    }
}

/// One thing a copy would do that the user could not have read off TMDB's answer. Each says
/// itself, so what the detail screen shows is what the tests assert, and the screen is a list of
/// sentences it did not write.
enum SeriesCopyNote: Equatable, Hashable, Identifiable, Sendable {
    /// TMDB lists specials — its season 0 — and they are left out: the app numbers seasons from
    /// 1 and has nowhere to put them.
    case droppedSpecials(episodes: Int)

    /// TMDB lists this season with no episodes — announced, not yet aired — and it is left out.
    /// There is nothing to watch in it, and the form cannot hold a season of none.
    case droppedSeasonWithoutEpisodes(season: Int)

    /// Nothing that survived is numbered this, and copying invents it at the episode count of
    /// the next season that did, so every season after it keeps the number TMDB gave it.
    case filledSeason(season: Int, episodes: Int, borrowedFrom: Int)

    /// Nothing in TMDB's answer survived, so the seasons are a single season of one episode for
    /// the user to correct.
    case noSeasonsAired

    /// The Position the form holds is not an episode the copied seasons have, so it lands on the
    /// nearest one they do.
    case movesPosition(from: Position, to: Position)

    var id: Self { self }

    /// What the detail screen says about it, and what the tests read. The wording is here rather
    /// than in the view because it is the promise ADR-0011 makes, not a matter of layout.
    var text: String {
        switch self {
        case .droppedSpecials(let episodes):
            "Leaves out the Specials — TMDB lists \(Self.episodes(episodes)) there, and the app numbers its seasons from 1."

        case .droppedSeasonWithoutEpisodes(let season):
            "Leaves out Season \(season), which TMDB lists with no episodes yet."

        case .filledSeason(let season, let episodes, let borrowedFrom):
            "TMDB lists no Season \(season), so it is copied as \(Self.episodes(episodes)) borrowed from Season \(borrowedFrom), keeping the later seasons on their own numbers."

        case .noSeasonsAired:
            "TMDB lists no aired seasons, so this copies a single season of one episode for you to correct."

        case .movesPosition(let from, let to):
            "Your position moves from \(from.shorthand) to \(to.shorthand), the nearest episode these seasons have."
        }
    }

    private static func episodes(_ count: Int) -> String {
        count == 1 ? "1 episode" : "\(count) episodes"
    }
}

/// What the form is holding while a search runs over it — everything a copy would land on top
/// of. A snapshot taken when the sheet opens, which is all it needs to be: the form is
/// underneath a sheet and nothing can touch it until the sheet is gone.
struct SeriesFormContents: Equatable, Sendable {
    var title: String
    var summary: String
    var seasons: Seasons

    /// Where the user says they have watched to, or nil where they have said nothing. Copying
    /// never sets it; the seasons it writes are what can move it, and a move is stated first.
    var position: Position?

    /// What a form nothing has been typed into holds — an empty Title and Description, the
    /// placeholder seasons, and nothing watched.
    static let new = SeriesFormContents(
        title: "",
        summary: "",
        seasons: .newSeriesPlaceholder,
        position: nil
    )

    /// Whether any of this is the user's own rather than what a new form offered. The whole of
    /// the seasons are compared and not merely how many there are: a user who left one season
    /// standing and corrected its episode count has typed as much as one who added a second.
    var isTypedInto: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || seasons != .newSeriesPlaceholder
    }
}

extension SeriesDetails {
    /// What copying this into `form` would write, and everything the user is owed about it
    /// before they tap Copy.
    ///
    /// The seasons flatten is the whole of the invention, and it is ADR-0011's: drop the
    /// specials, drop what has no episodes, fill whatever gap that leaves from the next season
    /// that survived — never renumber, because Position is the app's reason to exist — and fall
    /// back to a single season of one episode where nothing at all survives.
    func copy(over form: SeriesFormContents) -> SeriesCopy {
        let (copied, flattening) = flattenedSeasons()
        var notes = flattening

        if let position = form.position, !copied.contains(position) {
            notes.append(.movesPosition(from: position, to: copied.clamping(position)))
        }

        return SeriesCopy(
            title: name,
            summary: overview,
            seasons: copied,
            notes: notes,
            overwritesTheForm: form.isTypedInto
        )
    }

    /// The flatten itself, and what it owes the user for having done it. What survives is
    /// decided once and everything else is read off it: what was dropped is what did not
    /// survive, and what was filled is a number no survivor claims.
    private func flattenedSeasons() -> (Seasons, [SeriesCopyNote]) {
        let surviving = seasons
            .filter { $0.seasonNumber >= 1 && $0.episodeCount >= 1 }
            .sorted { $0.seasonNumber < $1.seasonNumber }
        let dropped = seasons
            .filter { !surviving.contains($0) }
            .sorted { $0.seasonNumber < $1.seasonNumber }

        var notes: [SeriesCopyNote] = dropped.compactMap { season in
            if season.seasonNumber == 0 {
                // Specials TMDB lists nothing in are nothing to tell the user about.
                season.episodeCount >= 1 ? .droppedSpecials(episodes: season.episodeCount) : nil
            } else {
                .droppedSeasonWithoutEpisodes(season: season.seasonNumber)
            }
        }

        guard let last = surviving.last else {
            return (.oneSeasonOfOneEpisode, notes + [.noSeasonsAired])
        }

        var counts: [Int] = []
        for number in 1...last.seasonNumber {
            if let listed = surviving.first(where: { $0.seasonNumber == number }) {
                counts.append(listed.episodeCount)
            } else if let next = surviving.first(where: { $0.seasonNumber > number }) {
                counts.append(next.episodeCount)
                notes.append(
                    .filledSeason(
                        season: number,
                        episodes: next.episodeCount,
                        borrowedFrom: next.seasonNumber
                    )
                )
            }
        }
        return (Seasons(episodeCounts: counts), notes)
    }
}
