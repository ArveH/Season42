import Foundation

/// What Copy would write into the movie form, worked out before it is tapped: a Title and a
/// Description.
///
/// A value rather than something the detail screen does, for the same reason a `SeriesCopy` is
/// one — every rule about copying lives in here, and a rule in a value is a rule with a test.
/// There are far fewer of them: a movie has no seasons, so nothing is flattened, nothing is
/// invented, and there is nothing the user is owed a note about before they tap.
///
/// It carries only what TMDB's answer speaks to. The Streaming Service and the watched state
/// are the user's alone and nothing in a Movie Details has a word to say about them, so nothing
/// here holds them.
struct MovieCopy: Equatable, Sendable {
    /// The movie's title, as TMDB has it — and the user's own the moment it lands in the form.
    let title: String

    /// What the movie is about, in TMDB's words. The Description, theirs to edit from there,
    /// and never a link back to where it came from (ADR-0002).
    let summary: String

    /// Whether copying would take something the user has already put in the form, which is what
    /// makes Copy ask before it writes.
    let overwritesTheForm: Bool
}

/// What the movie form is holding while a search runs over it — everything a copy would land on
/// top of. A snapshot taken when the sheet opens, which is all it needs to be: the form is
/// underneath a sheet and nothing can touch it until the sheet is gone.
///
/// The Streaming Service and the watched state are not here. A copy never touches them, so
/// whether they hold anything has no bearing on what a copy would cost.
struct MovieFormContents: Equatable, Sendable {
    var title: String
    var summary: String

    /// What a form nothing has been typed into holds — an empty Title and Description.
    static let new = MovieFormContents(title: "", summary: "")

    /// Whether any of this is the user's own rather than what a new form offered.
    var isTypedInto: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension MovieDetails {
    /// What copying this into `form` would write. Nothing is dropped and nothing is invented on
    /// the way, so unlike a series' copy there is nothing to state first.
    func copy(over form: MovieFormContents) -> MovieCopy {
        MovieCopy(title: title, summary: overview, overwritesTheForm: form.isTypedInto)
    }
}
