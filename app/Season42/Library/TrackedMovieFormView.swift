import SwiftUI

/// Hand-enters a Tracked Movie, or edits one already tracked. Like the series form it
/// only gathers values; every rule lives in `Library`, and whatever it refuses is shown
/// back to the user verbatim. A new movie starts unwatched — that is what a watchlist
/// entry is — so only an edit offers the watched toggle.
struct TrackedMovieFormView: View {
    let library: Library
    /// The movie being edited, or nil when the user is entering a new one.
    let editing: TrackedMovie?

    /// Where the search sheet gets its answers. The default is the live BFF, so the form
    /// gets the search without knowing there is a network.
    let movies: any MovieSearching

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var summary: String
    @State private var streamingService: StreamingService?
    @State private var isWatched: Bool
    @State private var failureMessage: String?
    @State private var isSearching = false

    init(
        library: Library,
        editing movie: TrackedMovie? = nil,
        movies: any MovieSearching = BffClient()
    ) {
        self.library = library
        self.editing = movie
        self.movies = movies
        _title = State(initialValue: movie?.title ?? "")
        _summary = State(initialValue: movie?.summary ?? "")
        _streamingService = State(initialValue: movie?.streamingService)
        _isWatched = State(initialValue: movie?.isWatched ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Searching is for what is typed, so the Title and the Search button
                    // that looks it up belong on one row.
                    HStack {
                        TextField("Title", text: $title)
                        Button("Search", systemImage: "magnifyingglass") { isSearching = true }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                    }
                    TextField("Description", text: $summary, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Where") {
                    StreamingServicePicker(library: library, selection: $streamingService)
                }

                if isEditing {
                    Section("Watched") {
                        Toggle("Watched", isOn: $isWatched)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Movie" : "Track a Movie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add", action: submit)
                }
            }
            .alert(
                isEditing ? "Couldn't save the movie" : "Couldn't add the movie",
                isPresented: .init(
                    get: { failureMessage != nil },
                    set: { if !$0 { failureMessage = nil } }
                ),
                presenting: failureMessage
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
            // The sheet opens over what the form holds and writes back nothing but a copy the
            // user asked for: what they do in there costs them the form only when they choose
            // to take something from it.
            .sheet(isPresented: $isSearching) {
                MovieSearchSheet(over: contents, movies: movies, onCopy: apply)
            }
        }
    }

    private var isEditing: Bool { editing != nil }

    /// What the form is holding, for the search sheet to work out what a copy would land on
    /// top of. The Streaming Service and the watched state are not among it: a copy never
    /// touches them, so whether they hold anything has no bearing on what a copy would cost.
    private var contents: MovieFormContents {
        MovieFormContents(title: title, summary: summary)
    }

    /// Takes what the user copied off a Movie Details and closes the sheet. Everything copied
    /// is theirs from here — as editable as if they had typed it, and saved no sooner.
    ///
    /// Only the two fields TMDB's answer speaks to are written. The Streaming Service and the
    /// watched state are untouched, and there is nothing else for a copy to move: a movie has
    /// no seasons and so no Position for copied ones to push around.
    private func apply(_ copied: MovieCopy) {
        title = copied.title
        summary = copied.summary
        isSearching = false
    }

    private func submit() {
        do {
            if let editing {
                try library.updateTrackedMovie(
                    editing,
                    title: title,
                    summary: summary,
                    streamingService: streamingService,
                    isWatched: isWatched
                )
            } else {
                try library.addTrackedMovie(
                    title: title,
                    summary: summary,
                    streamingService: streamingService
                )
            }
            dismiss()
        } catch {
            failureMessage = error.localizedDescription
        }
    }
}

#Preview {
    TrackedMovieFormView(library: try! Library.inMemory())
}
