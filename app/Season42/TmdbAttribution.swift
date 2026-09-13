import SwiftUI

/// What TMDB's terms ask of a screen that shows its data or its images: the mark, and the
/// wording that says what on the screen is TMDB's and that the app is not endorsed by it.
/// Drawn under all three sheets that search TMDB — series, movies, and the one that names a
/// service — whatever state the search is in, because the wording is owed for the data being
/// asked for, not only for data that arrived. A `Section` of its own rather than a footer on
/// the results, because an idle search has no results section to hang it from; the sheets
/// drop it straight into their `Form`.
///
/// TMDB's own sentence is last, verbatim, and is the same under every sheet: the terms
/// dictate its words and a paraphrase of it is not the thing they asked for. The same
/// sentence is in the root README and on the privacy page under `site/`, so a reworded terms
/// page is a change in three places and not only this one. What comes before it differs,
/// because what the sheet is showing differs. The series and movie sheets show details and
/// posters, which are TMDB's own. The logo sheet shows Watch Providers, which reach TMDB from
/// JustWatch — so it carries JustWatch's fixed clause as well, in JustWatch's own words for
/// the same reason TMDB's sentence is in TMDB's. Both say "streaming service" rather than
/// Watch Provider: the glossary's term is for the code, and a user has only ever registered
/// streaming services.
///
/// That JustWatch credit is prudence, not remediation: TMDB's "we will revoke access"
/// language sits on the per-title watch provider endpoints, and the BFF calls only the
/// provider directory, whose reference page carries no such note. Nothing was in breach
/// without it. It is here because it is the same upstream dataset and the cost is a clause in
/// a sentence that was being written anyway.
///
/// The mark is bundled in the asset catalogue rather than fetched, on ADR-0013's argument for
/// a Poster: an attribution that went missing exactly when the BFF was unreachable would be
/// missing when it was least excusable. It is TMDB's `blue_square_2`, a teal-to-blue gradient
/// on nothing, which reads against light and dark alike, so there is one of it.
///
/// Not tappable. The user is part-way through something, and a link out to a browser is a way
/// to lose their place. The detail screens the search sheets push get no copy of their own:
/// one Back brings this one up.
struct TmdbAttribution: View {
    /// What the sheet under this attribution is showing, which is what its wording names
    /// before it gets to TMDB's own sentence.
    enum Credits: CaseIterable {
        /// The series and movie search sheets: details and posters, TMDB's own.
        case seriesAndMovies
        /// The logo sheet: Watch Providers, which TMDB has from JustWatch.
        case watchProviders

        /// The wording, with the sentence TMDB's terms require verbatim as its last.
        var wording: String {
            switch self {
            case .seriesAndMovies:
                "Series and movie details and posters are provided by TMDB. " + Self.requiredSentence
            case .watchProviders:
                "Streaming service names and logos come by way of TMDB; "
                    + "streaming data provided by JustWatch. " + Self.requiredSentence
            }
        }

        /// The sentence TMDB's terms dictate, word for word. Not to be edited into something
        /// that reads better: what it is for is being exactly this.
        private static let requiredSentence =
            "This product uses TMDB and the TMDB APIs but is not endorsed, certified, or otherwise approved by TMDB."
    }

    /// The asset catalogue's name for the mark.
    static let markName = "TmdbMark"

    let credits: Credits

    init(_ credits: Credits) {
        self.credits = credits
    }

    var body: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                Image(Self.markName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44)
                    .accessibilityLabel("TMDB")
                Text(credits.wording)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview("Light") {
    Form {
        TmdbAttribution(.seriesAndMovies)
        TmdbAttribution(.watchProviders)
    }
}

#Preview("Dark") {
    Form {
        TmdbAttribution(.seriesAndMovies)
        TmdbAttribution(.watchProviders)
    }
    .preferredColorScheme(.dark)
}
