import SwiftUI

/// The mark, and the wording that says what the app takes from TMDB and that TMDB has not
/// endorsed it. The notice is owed by the application rather than by any one screen, so
/// Settings is where it is discharged and the tabs that draw posters and logos carry none:
/// ADR-0019 has the reading and the alternatives. The three sheets that search TMDB — series,
/// movies, and the one that names a service — carry it too, as redundancy the ADR explains
/// rather than a second requirement.
///
/// Under a sheet it is drawn whatever state the search is in, because the wording is owed for
/// the data being asked for, not only for data that arrived. A `Section` of its own rather
/// than a footer on anything, because an idle search has no results section to hang it from
/// and Settings' About section is not what it speaks for; every caller drops it straight into
/// its `Form`.
///
/// TMDB's own sentence is last, verbatim, and is the same everywhere: the terms dictate its
/// words and a paraphrase of it is not the thing they asked for. The same sentence is in the
/// root README and on the privacy page under `site/`, so a reworded terms page is a change in
/// three places and not only this one. What comes before it is whichever halves the surface
/// speaks for. All of them say "streaming service" rather than Watch Provider: the glossary's
/// term is for the code, and a user has only ever registered streaming services.
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
/// Not tappable anywhere, Settings included — the terms ask for the mark's presence and not
/// for a link, and ADR-0019 has the rest of that argument. Under a sheet there is a second
/// reason: the user is part-way through something, and a link out to a browser is a way to
/// lose their place. The detail screens the search sheets push get no copy of their own: one
/// Back brings this one up.
struct TmdbAttribution: View {
    /// What the surface under this attribution speaks for, which is what its wording names
    /// before it gets to TMDB's own sentence.
    enum Credits: CaseIterable {
        /// The series and movie search sheets: details and posters, TMDB's own.
        case seriesAndMovies
        /// The logo sheet: Watch Providers, which TMDB has from JustWatch.
        case watchProviders
        /// Settings: the whole app, so both halves of what it takes from TMDB.
        case wholeApp

        /// The wording, with the sentence TMDB's terms require verbatim as its last. Each
        /// surface names the halves it speaks for; Settings speaks for the app, so it names
        /// both. The halves are written once each so that rewording one is one edit and the
        /// app-level notice cannot drift out of step with the sheet that says the same thing.
        var wording: String {
            switch self {
            case .seriesAndMovies:
                "\(Self.detailsAndPosters) \(Self.requiredSentence)"
            case .watchProviders:
                "\(Self.streamingServices) \(Self.requiredSentence)"
            case .wholeApp:
                "\(Self.detailsAndPosters) \(Self.streamingServices) \(Self.requiredSentence)"
            }
        }

        /// What the app takes from TMDB directly.
        private static let detailsAndPosters =
            "Series and movie details and posters are provided by TMDB."

        /// What reaches TMDB from JustWatch, with JustWatch's clause in JustWatch's own words.
        private static let streamingServices =
            "Streaming service names and logos come by way of TMDB; "
            + "streaming data provided by JustWatch."

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
        TmdbAttribution(.wholeApp)
    }
}

#Preview("Dark") {
    Form {
        TmdbAttribution(.seriesAndMovies)
        TmdbAttribution(.watchProviders)
        TmdbAttribution(.wholeApp)
    }
    .preferredColorScheme(.dark)
}
