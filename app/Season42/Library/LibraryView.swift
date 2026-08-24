import SwiftUI

/// The Library tab: everything the user tracks, series and movies alike, and the one
/// place new entries are created.
struct LibraryView: View {
    let library: Library

    @State private var adding: NewEntry?

    var body: some View {
        NavigationStack {
            Group {
                if library.entries.isEmpty {
                    ContentUnavailableView(
                        "Nothing tracked yet",
                        systemImage: "books.vertical",
                        description: Text("Add a series or a movie to start tracking it.")
                    )
                } else {
                    List(library.entries) { entry in
                        switch entry {
                        case .series(let series): TrackedSeriesRow(series: series)
                        case .movie(let movie): TrackedMovieRow(library: library, movie: movie)
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu("Add", systemImage: "plus") {
                        Button("Series", systemImage: "tv") { adding = .series }
                        Button("Movie", systemImage: "film") { adding = .movie }
                    }
                }
            }
            .sheet(item: $adding) { entry in
                switch entry {
                case .series: AddTrackedSeriesView(library: library)
                case .movie: AddTrackedMovieView(library: library)
                }
            }
        }
    }

    /// Which add form the user asked for, and so which sheet is up.
    private enum NewEntry: String, Identifiable {
        case series
        case movie

        var id: String { rawValue }
    }
}

private struct TrackedSeriesRow: View {
    let series: TrackedSeries

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(series.title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let nextEpisodeDate = series.nextEpisodeDate {
                Text("Next episode \(nextEpisodeDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        var parts = [series.status.title, series.position?.shorthand ?? "Not started"]
        if let streamingService = series.streamingService {
            parts.append(streamingService)
        }
        return parts.joined(separator: " · ")
    }
}

/// A movie and its one piece of state: seen, or still on the watchlist. The toggle goes
/// both ways, and `Library` decides what marking it watched does to the date.
private struct TrackedMovieRow: View {
    let library: Library
    let movie: TrackedMovie

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

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
        var parts = ["Movie"] + movie.watchedState
        if let streamingService = movie.streamingService {
            parts.append(streamingService)
        }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    LibraryView(library: try! Library.inMemory())
}
