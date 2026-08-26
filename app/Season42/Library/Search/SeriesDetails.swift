import Foundation

/// Everything the app shows about one series the user opened from a search, as the BFF answers
/// with it: what it is called, what it is called where it was made, what it is about, and what
/// seasons it has. This is the whole of it — the poster, the networks and the ratings TMDB also
/// knows are not part of the ask.
///
/// Someone else's data, never stored. The id is TMDB's, the same one the Series Match it was
/// opened from carried, and nothing in the Library ever holds one (ADR-0002).
struct SeriesDetails: Decodable, Equatable, Identifiable, Sendable {
    /// TMDB's id — the id this was asked for, answered back.
    let id: Int

    let name: String

    /// What the series is called where it was made, which for a series made elsewhere is the
    /// thing that tells two similar English titles apart. The same as `name` often enough, and
    /// empty where TMDB carries none.
    let originalName: String

    /// What the series is about, in TMDB's words. Empty where TMDB carries none.
    let overview: String

    /// Every season TMDB lists, in its order, which is season order. Season 0 — the specials —
    /// is among them: the BFF passes it through rather than making the app's decision for it.
    let seasons: [SeriesSeason]
}

/// One season of a Series Details, as its number and how many episodes it has.
struct SeriesSeason: Decodable, Equatable, Identifiable, Sendable {
    /// Numbered as TMDB numbers them, from 1, with 0 for the specials. Unique within one
    /// series, which is what makes it the row's identity.
    var id: Int { seasonNumber }

    let seasonNumber: Int

    let episodeCount: Int
}
