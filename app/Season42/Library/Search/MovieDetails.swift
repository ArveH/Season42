import Foundation

/// Everything the app shows about one movie the user opened from a search, as the BFF answers
/// with it: what it is called, what it is called where it was made, and what it is about. This
/// is the whole of it — the runtime and the ratings TMDB also knows are not part of the ask.
///
/// There are no seasons, which is the whole of what separates it from a Series Details: a movie
/// is one thing to watch, so nothing here is flattened and nothing about a copy is invented.
///
/// The BFF also answers whether there is a poster to be had, and nothing here reads it: a movie
/// carries no Poster yet, and a field the app has no use for is a field it does not decode. It
/// is the ask the Poster will be made with when there is one to make.
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
}
