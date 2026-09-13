import SwiftUI

/// The sheet the Search button beside the movie form's Title opens: a search box, and the
/// titles the BFF matched. A sheet over the form rather than a push into it, because the form
/// is itself a sheet with Cancel and Save in its bar, and two competing ways out in one bar is
/// the thing to avoid.
///
/// Every rule about the search is `MovieSearch`'s. This renders what it says, and writes
/// nothing back to the form it was opened over — the box it opened pre-filled from is a copy
/// of the Title, not the Title. The one thing that ever reaches the form is a copy the user
/// asked for on the detail screen, and it goes there by way of `onCopy`.
///
/// Tapping a match pushes its details onto the sheet's own stack, so Back comes straight back
/// to the results the search already has: trying a second match is one tap, not a second
/// search.
struct MovieSearchSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var search: MovieSearch

    /// What the form was holding when Search was tapped — the Title the box opens with, and
    /// the rest of what a copy would land on top of.
    private let form: MovieFormContents

    /// What to do with a copy the user asked for. The form writes it in and closes this sheet:
    /// the form owns the sheet, so the form is what closes it.
    private let onCopy: (MovieCopy) -> Void

    /// - Parameters:
    ///   - form: what the form holds. Its Title is what the box opens holding, and an empty one
    ///     is an ordinary case: the box is simply ready to type in.
    ///   - movies: where the search gets its answers.
    ///   - onCopy: what to do with what the user copied.
    init(
        over form: MovieFormContents,
        movies: any MovieSearching,
        onCopy: @escaping (MovieCopy) -> Void
    ) {
        self.form = form
        self.onCopy = onCopy
        _search = State(initialValue: MovieSearch(text: form.title, movies: movies))
    }

    var body: some View {
        NavigationStack {
            Form {
                searchSection
                resultsSection
                TmdbAttribution(.seriesAndMovies)
            }
            .navigationDestination(for: MovieMatch.self) { match in
                MovieDetailsView(match: match, search: search, form: form, onCopy: onCopy)
            }
            .navigationTitle("Find a movie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            // Tapping Search with a Title already typed means searching for it, so the sheet
            // arrives with the answer already on its way. An empty Title searches for nothing
            // and this costs nothing: what opens is an empty box.
            .task { await search.search() }
        }
    }

    /// The text being searched for, and the button that searches for it again after it has
    /// been corrected.
    private var searchSection: some View {
        Section {
            HStack {
                TextField("Movie title", text: $search.text)
                    .submitLabel(.search)
                    .onSubmit { runSearch() }
                Button("Search", systemImage: "magnifyingglass") { runSearch() }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
            }
        } footer: {
            Text("Correcting this doesn't change the title on the form.")
        }
    }

    /// What the search has to say. A failure is said here rather than in an alert: the alerts
    /// around the form are for what `Library` refuses, and a BFF that isn't there refuses
    /// nothing — the user can close this and type the movie in by hand.
    @ViewBuilder
    private var resultsSection: some View {
        switch search.state {
        case .idle:
            EmptyView()

        case .searching:
            Section {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Searching…")
                        .foregroundStyle(.secondary)
                }
            }

        case .results(let matches):
            Section("Matches") {
                // The match itself is what the row is pushed with: there is nothing to look
                // up again on the way to its details, and the title is on screen from the
                // first frame of the screen it pushes.
                ForEach(matches) { match in
                    NavigationLink(match.title, value: match)
                }
            }

        case .matchedNothing:
            Section {
                Text("Nothing matched that title. Try another spelling, or close this and enter it yourself.")
                    .foregroundStyle(.secondary)
            }

        case .failed:
            Section {
                Label(
                    "Couldn't reach the search service. You can still enter the movie yourself.",
                    systemImage: "exclamationmark.triangle"
                )
                .foregroundStyle(.secondary)
            }
        }
    }

    private func runSearch() {
        Task { await search.search() }
    }
}

#Preview("Matches") {
    MovieSearchSheet(over: .searching(for: "arriv"), movies: PreviewMovies()) { _ in }
}

#Preview("From an empty title") {
    MovieSearchSheet(over: .new, movies: PreviewMovies()) { _ in }
}

#Preview("Nothing matched") {
    MovieSearchSheet(over: .searching(for: "zzz"), movies: PreviewMovies(matches: [])) { _ in }
}

#Preview("Unreachable") {
    MovieSearchSheet(over: .searching(for: "arriv"), movies: PreviewMovies(fails: true)) { _ in }
}

private extension MovieFormContents {
    /// A new form with only a Title typed into it, for the previews above.
    static func searching(for title: String) -> MovieFormContents {
        var form = MovieFormContents.new
        form.title = title
        return form
    }
}

/// A BFF for the previews above, so every state of the search can be seen without one
/// running. Not behind `#if DEBUG`: a `#Preview` is compiled in every configuration, so what
/// it calls has to be too.
private struct PreviewMovies: MovieSearching {
    var matches: [MovieMatch] = [
        MovieMatch(id: 329865, title: "Arrival"),
        MovieMatch(id: 438631, title: "Dune"),
    ]
    var fails = false

    var details = MovieDetails(
        title: "Arrival",
        originalTitle: "Arrival",
        overview: "An expert linguist is recruited by the military to determine whether the "
            + "visitors come in peace or are a threat.",
        hasPoster: true
    )

    func movies(matching text: String) async throws -> [MovieMatch] {
        if fails { throw BffError.notServed(status: 502) }
        return matches
    }

    func movieDetails(for id: Int) async throws -> MovieDetails {
        if fails { throw BffError.notServed(status: 502) }
        return details
    }

    func moviePoster(for id: Int) async throws -> Data {
        if fails { throw BffError.notServed(status: 502) }
        return PreviewPoster.bytes(.systemTeal)
    }
}
