import Foundation

/// Everything the app shows about one series the user opened from a search, as the BFF answers
/// with it: what it is called, what it is called where it was made, what it is about, whether
/// there is a poster to be had, and what seasons it has. This is the whole of it — the networks
/// and the ratings TMDB also knows are not part of the ask.
///
/// Someone else's data, never stored. Not even the id it was asked for comes back: the app
/// already has that from the Series Match it opened, and nothing in the Library ever holds one
/// (ADR-0002).
struct SeriesDetails: Decodable, Equatable, Sendable {
    let name: String

    /// What the series is called where it was made, which for a series made elsewhere is the
    /// thing that tells two similar English titles apart. The same as `name` often enough, and
    /// empty where TMDB carries none.
    let originalName: String

    /// What the series is about, in TMDB's words. Empty where TMDB carries none.
    let overview: String

    /// Whether TMDB has a poster for this series, and so whether there is anything to ask for.
    /// A yes or a no and never TMDB's path to it: the poster is asked for by the same id these
    /// details were, which is what makes that ask safe with no allowlist behind it (ADR-0012).
    ///
    /// It says what TMDB's answer said, not that the bytes will arrive. A series can advertise
    /// a poster the image host then refuses, so a `true` here is a reason to ask rather than a
    /// promise, and the screen has to survive a poster that never comes either way.
    let hasPoster: Bool

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
