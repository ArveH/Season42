import SwiftUI

/// The Library tab: everything the user tracks, series and movies alike, narrowed by
/// whatever they have searched or filtered for, and the one place entries are created,
/// edited and deleted. Which entries a filter keeps is `Library`'s to decide; this view
/// holds the filter the user has set and shows what comes back.
struct LibraryView: View {
    let library: Library

    @State private var filter = LibraryFilter()
    @State private var form: EntryForm?
    @State private var deleting: PendingDeletion?

    var body: some View {
        NavigationStack {
            Group {
                if library.entries.isEmpty {
                    ContentUnavailableView(
                        "Nothing tracked yet",
                        systemImage: "books.vertical",
                        description: Text("Add a series or a movie to start tracking it.")
                    )
                } else if entries.isEmpty {
                    noMatches
                } else {
                    List(entries) { entry in
                        row(for: entry)
                            .swipeActions(edge: .trailing) {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    deleting = PendingDeletion(entry)
                                }
                                Button("Edit", systemImage: "pencil") {
                                    form = .editing(entry)
                                }
                                .tint(.accentColor)
                            }
                    }
                }
            }
            .navigationTitle("Library")
            .searchable(text: $filter.searchText, prompt: "Search titles")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    filterMenu
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu("Add", systemImage: "plus") {
                        Button("Series", systemImage: "tv") { form = .newSeries }
                        Button("Movie", systemImage: "film") { form = .newMovie }
                    }
                }
            }
            .sheet(item: $form) { form in
                switch form {
                case .newSeries: TrackedSeriesFormView(library: library)
                case .newMovie: TrackedMovieFormView(library: library)
                case .editing(.series(let series)):
                    TrackedSeriesFormView(library: library, editing: series)
                case .editing(.movie(let movie)):
                    TrackedMovieFormView(library: library, editing: movie)
                }
            }
            .confirmationDialog(
                "Delete this entry?",
                isPresented: .init(
                    get: { deleting != nil },
                    set: { if !$0 { deleting = nil } }
                ),
                presenting: deleting
            ) { pending in
                Button("Delete \(pending.title)", role: .destructive) {
                    library.delete(pending.entry)
                }
            } message: { _ in
                Text("This can't be undone.")
            }
        }
    }

    private var entries: [LibraryEntry] { library.entries(matching: filter) }

    /// A row, tappable on its text to edit what it names. The movie row keeps its own
    /// watched button, so the tap sits on the text rather than the whole row — nesting
    /// one tappable thing inside another is what a row like that can't have.
    @ViewBuilder
    private func row(for entry: LibraryEntry) -> some View {
        switch entry {
        case .series(let series):
            TrackedSeriesRow(series: series) { form = .editing(entry) }
        case .movie(let movie):
            TrackedMovieRow(library: library, movie: movie) { form = .editing(entry) }
        }
    }

    /// Everything the user tracks is still there — their search or filter is simply
    /// hiding it — so this says so rather than reading like an empty Library.
    private var noMatches: some View {
        ContentUnavailableView(
            "Nothing matches",
            systemImage: "line.3.horizontal.decrease.circle",
            description: Text("No tracked series or movie matches what you're looking for.")
        )
    }

    private var filterMenu: some View {
        Menu {
            Picker("Show", selection: $filter.kind) {
                Text("Series and movies").tag(LibraryEntry.Kind?.none)
                ForEach(LibraryEntry.Kind.allCases) { kind in
                    Text(kind.title).tag(LibraryEntry.Kind?.some(kind))
                }
            }
            Picker("Status", selection: $filter.status) {
                Text("Any status").tag(WatchStatus?.none)
                ForEach(WatchStatus.allCases, id: \.self) { status in
                    Text(status.title).tag(WatchStatus?.some(status))
                }
            }
            if filter.isNarrowing {
                Button("Clear filter", systemImage: "xmark.circle") { filter = LibraryFilter() }
            }
        } label: {
            Label(
                "Filter",
                systemImage: filter.isNarrowing
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
        }
    }

    /// A Library Entry the user has asked to delete, with its title taken down as plain
    /// text: the confirmation is still on screen as the entry goes, and by then there is
    /// no stored entry left to read a title off.
    private struct PendingDeletion: Identifiable {
        let entry: LibraryEntry
        let title: String

        var id: LibraryEntry.ID { entry.id }

        init(_ entry: LibraryEntry) {
            self.entry = entry
            self.title = entry.title
        }
    }

    /// Which form is up: a new entry of one kind or the other, or an edit of what the
    /// user tapped.
    private enum EntryForm: Identifiable {
        case newSeries
        case newMovie
        case editing(LibraryEntry)

        var id: String {
            switch self {
            case .newSeries: "new-series"
            case .newMovie: "new-movie"
            case .editing(let entry): "\(entry.id)"
            }
        }
    }
}

private struct TrackedSeriesRow: View {
    let series: TrackedSeries
    let edit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(series.title)
                .font(.headline)
            (Text(subtitle) + StreamingServiceSegment(service: series.streamingService).text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let nextEpisodeDate = series.nextEpisodeDate {
                Text("Next episode \(nextEpisodeDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .onTapGesture(perform: edit)
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        [series.status.title, series.position?.shorthand ?? "Not started"]
            .joined(separator: " · ")
    }
}

/// A movie and its one piece of state: seen, or still on the watchlist. The toggle goes
/// both ways, and `Library` decides what marking it watched does to the date.
private struct TrackedMovieRow: View {
    let library: Library
    let movie: TrackedMovie
    let edit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.headline)
                (Text(subtitle) + StreamingServiceSegment(service: movie.streamingService).text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .onTapGesture(perform: edit)

            Button(
                movie.isWatched ? "Mark unwatched" : "Mark watched",
                systemImage: movie.isWatched ? "checkmark.circle.fill" : "circle"
            ) {
                library.setWatched(!movie.isWatched, on: movie)
            }
            .labelStyle(.iconOnly)
            .font(.title2)
            .buttonStyle(.plain)
            .foregroundStyle(movie.isWatched ? .primary : .secondary)
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        (["Movie"] + movie.watchedState).joined(separator: " · ")
    }
}

#Preview {
    LibraryView(library: try! Library.inMemory())
}
