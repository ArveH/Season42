import Foundation

/// Everything the app shows about one movie the user opened from a search, as the BFF answers
/// with it: what it is called, what it is called where it was made, and what it is about. This
/// is the whole of it — the runtime and the ratings TMDB also knows are not part of the ask.
///
/// There are no seasons, which is the whole of what separates it from a Series Details: a movie
/// is one thing to watch, so nothing here is flattened and nothing about a copy is invented.
///
/// Someone else's data, never stored. Not even the id it was asked for comes back: the app
/// already has that from the Movie Match it opened, and nothing in the Library ever holds one
/// (ADR-0002).
struct MovieDetails: Decodable, Equatable, Sendable {
    let title: String

    /// What the movie is called where it was made, which for one made elsewhere is the thing
    /// that tells two similar English titles apart. The same as `title` often enough, and empty
    /// where TMDB carries none.
    let originalTitle: String

    /// What the movie is about, in TMDB's words. Empty where TMDB carries none.
    let overview: String

    /// Whether TMDB has a poster for this movie, and so whether there is anything to ask for.
    /// A yes or a no and never TMDB's path to it: the poster is asked for by the same id these
    /// details were, which is what makes that ask safe with no allowlist behind it (ADR-0012).
    ///
    /// It says what TMDB's answer said, not that the bytes will arrive. A movie can advertise a
    /// poster the image host then refuses, so a `true` here is a reason to ask rather than a
    /// promise, and the screen has to survive a poster that never comes either way.
    let hasPoster: Bool
}
