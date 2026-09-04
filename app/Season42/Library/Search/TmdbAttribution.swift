import SwiftUI

/// What TMDB's terms ask of a screen that shows its data: the mark, and the wording that says
/// the details and posters are TMDB's and that the app is not endorsed by it. Drawn under the
/// results of both search sheets, whatever state the search is in — the wording is owed for
/// the data being asked for, not only for data that arrived.
///
/// The mark is bundled in the asset catalogue rather than fetched, on ADR-0013's argument for
/// a Poster: an attribution that went missing exactly when the BFF was unreachable would be
/// missing when it was least excusable. It is TMDB's `blue_square_2`, a teal-to-blue gradient
/// on nothing, which reads against light and dark alike, so there is one of it.
///
/// Not tappable. The user is mid-search, and a link out to a browser is a way to lose their
/// place. The detail screens that push from a sheet get no copy: one Back brings this one up.
struct TmdbAttribution: View {
    /// The asset catalogue's name for the mark.
    static let markName = "TmdbMark"

    /// The wording, with the sentence TMDB's terms require verbatim as its second half.
    static let wording = "Series and movie details and posters are provided by TMDB. "
        + "This product uses the TMDB API but is not endorsed or certified by TMDB."

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(Self.markName)
                .resizable()
                .scaledToFit()
                .frame(width: 44)
                .accessibilityLabel("TMDB")
            Text(Self.wording)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Light") {
    List { TmdbAttribution() }
}

#Preview("Dark") {
    List { TmdbAttribution() }
        .preferredColorScheme(.dark)
}
