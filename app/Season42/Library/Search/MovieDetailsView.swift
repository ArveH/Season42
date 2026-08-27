import SwiftUI

/// What tapping a movie match pushes: its title, what it is called where it was made, what it
/// is about, and the Copy that fills the form in with them. Back is the navigation bar's own,
/// and the results are still listed underneath it, so trying a second match is one tap rather
/// than a fresh search.
///
/// Shorter than the series' detail screen by everything a movie hasn't got: no poster, no
/// seasons, and so no notes — nothing is dropped or invented on the way into the form, so there
/// is nothing to state before Copy is tapped.
///
/// Every rule about reading the details is `MovieSearch`'s — opening a match is the second half
/// of the search, not a thing of its own.
struct MovieDetailsView: View {
    /// The match that was tapped. Its title is on screen from the first frame, before any
    /// details have arrived.
    let match: MovieMatch

    /// The search this was pushed from, which is what reads the details and holds them.
    let search: MovieSearch

    /// What the form was holding when the sheet opened, which is what a copy would land on top
    /// of. It cannot have moved since: the form is underneath a sheet.
    let form: MovieFormContents

    /// Hands the copy to the form, which writes it in and closes the sheet. Nothing here
    /// dismisses anything: the form owns the sheet, so the form is what closes it.
    let onCopy: (MovieCopy) -> Void

    /// The copy the user asked for over a form they had already typed into, held while they are
    /// asked whether they meant it. Nil the rest of the time.
    @State private var pendingCopy: MovieCopy?

    var body: some View {
        Form {
            switch search.detailsState {
            case .loading:
                loadingSection

            case .loaded(let details):
                aboutSection(details)
                copySection(details.copy(over: form))

            case .failed:
                failedSection
            }
        }
        // The match's title, so the bar says which one was tapped before anything has arrived
        // and doesn't change under the user once it has.
        .navigationTitle(match.title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Replace what you've entered?",
            isPresented: .init(
                get: { pendingCopy != nil },
                set: { if !$0 { pendingCopy = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingCopy
        ) { copy in
            Button("Copy", role: .destructive) { onCopy(copy) }
            Button("Keep what I typed", role: .cancel) {}
        } message: { _ in
            Text(
                "The title and the description on the form are replaced. "
                    + "Your streaming service and whether you have watched it are left alone."
            )
        }
        .task { await search.open(match) }
    }

    private var loadingSection: some View {
        Section {
            HStack(spacing: 12) {
                ProgressView()
                Text("Loading details…")
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The failure, said here rather than in an alert: the alerts around the form are for what
    /// `Library` refuses, and a BFF that isn't there refuses nothing. Back is what to do about
    /// it, and it costs nothing — the results it returns to are still listed.
    private var failedSection: some View {
        Section {
            Label(
                "Couldn't load the details. Go back and pick another match, or close this and enter the movie yourself.",
                systemImage: "exclamationmark.triangle"
            )
            .foregroundStyle(.secondary)
        }
    }

    /// The titles and the overview. The original title sits under the title rather than beside
    /// it in the bar, because a title long enough to be worth telling apart is a title too long
    /// for a navigation bar to show twice.
    private func aboutSection(_ details: MovieDetails) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(details.title)
                    .font(.headline)
                if !details.originalTitle.isEmpty {
                    Text(details.originalTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if !details.overview.isEmpty {
                Text(details.overview)
            }
        }
    }

    /// Copy, and what it would cost. A form the user has typed into is asked about first; a
    /// fresh one is simply filled in, because there is nothing there to lose.
    private func copySection(_ copy: MovieCopy) -> some View {
        Section {
            Button("Copy into the form") {
                if copy.overwritesTheForm {
                    pendingCopy = copy
                } else {
                    onCopy(copy)
                }
            }
        } footer: {
            Text(
                "Fills in the title and the description, and leaves the rest to you. "
                    + "Nothing is saved until you save the form."
            )
        }
    }
}

#Preview("Details") {
    PreviewMovieDetailScreen(movies: PreviewMovieDetails())
}

#Preview("Over a form already filled in") {
    PreviewMovieDetailScreen(
        movies: PreviewMovieDetails(),
        form: MovieFormContents(title: "Arival", summary: "The one with the squid language.")
    )
}

#Preview("One title only") {
    PreviewMovieDetailScreen(movies: PreviewMovieDetails(originalTitle: "", overview: ""))
}

#Preview("Unreachable") {
    PreviewMovieDetailScreen(movies: PreviewMovieDetails(fails: true))
}

/// The detail screen as the sheet pushes it — over a search, because the search is what reads
/// the details. Not behind `#if DEBUG`: a `#Preview` is compiled in every configuration, so
/// what it calls has to be too.
private struct PreviewMovieDetailScreen: View {
    let movies: any MovieSearching
    var form: MovieFormContents = .new

    private var match: MovieMatch { MovieMatch(id: 329865, title: "Arrival") }

    var body: some View {
        NavigationStack {
            MovieDetailsView(
                match: match,
                search: MovieSearch(text: match.title, movies: movies),
                form: form,
                onCopy: { _ in }
            )
        }
    }
}

/// A BFF for the previews above, so every state of the screen can be seen without one running.
private struct PreviewMovieDetails: MovieSearching {
    var originalTitle = "Arrival (original)"
    var overview = "Taking place after alien crafts land around the world, an expert linguist is "
        + "recruited by the military to determine whether they come in peace or are a threat."
    var fails = false

    func movies(matching text: String) async throws -> [MovieMatch] { [] }

    func movieDetails(for id: Int) async throws -> MovieDetails {
        if fails { throw BffError.notServed(status: 502) }
        return MovieDetails(title: "Arrival", originalTitle: originalTitle, overview: overview)
    }
}
