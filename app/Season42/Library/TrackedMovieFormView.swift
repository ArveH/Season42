import SwiftUI

/// Hand-enters a Tracked Movie, or edits one already tracked. Like the series form it
/// only gathers values; every rule lives in `Library`, and whatever it refuses is shown
/// back to the user verbatim. A new movie starts unwatched — that is what a watchlist
/// entry is — so only an edit offers the watched toggle.
struct TrackedMovieFormView: View {
    let library: Library
    /// The movie being edited, or nil when the user is entering a new one.
    let editing: TrackedMovie?

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var summary: String
    @State private var streamingService: String
    @State private var isWatched: Bool
    @State private var failureMessage: String?

    init(library: Library, editing movie: TrackedMovie? = nil) {
        self.library = library
        self.editing = movie
        _title = State(initialValue: movie?.title ?? "")
        _summary = State(initialValue: movie?.summary ?? "")
        _streamingService = State(initialValue: movie?.streamingService ?? "")
        _isWatched = State(initialValue: movie?.isWatched ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("Description", text: $summary, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Where") {
                    TextField("Streaming service", text: $streamingService)
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
        }
    }

    private var isEditing: Bool { editing != nil }

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
