import SwiftUI

/// The Watching tab: the series the user is actively into, most recently watched first,
/// each one tap away from its next episode. Every rule about what that tap does lives in
/// `Library`; this view only names the episode and calls it.
struct WatchingView: View {
    let library: Library

    var body: some View {
        NavigationStack {
            Group {
                if library.watching.isEmpty {
                    ContentUnavailableView(
                        "Nothing on the go",
                        systemImage: "play.circle",
                        description: Text("Series you set to Watching show up here.")
                    )
                } else {
                    List(library.watching) { series in
                        WatchingRow(library: library, series: series)
                    }
                }
            }
            .navigationTitle("Watching")
        }
    }
}

private struct WatchingRow: View {
    let library: Library
    let series: TrackedSeries

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(series.title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                if series.isAtLastKnownEpisode {
                    endOfSeriesQuestion
                } else if let nextEpisode = series.nextEpisode {
                    Button("Mark \(nextEpisode.shorthand) watched") {
                        library.markNextEpisodeWatched(series)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if series.position != nil {
                    Button("Un-watch", systemImage: "arrow.uturn.backward") {
                        library.unwatchLastEpisode(series)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// Shown in place of the "watched it" button once the Position is at the last episode
    /// the user has entered: the only ways on are out of the Watching list.
    private var endOfSeriesQuestion: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Finished the series, or waiting for more?")
                .font(.subheadline)
            HStack {
                Button("Finished") { library.setStatus(.finished, on: series) }
                Button("Waiting") { library.setStatus(.waiting, on: series) }
            }
            .buttonStyle(.bordered)
        }
    }

    private var subtitle: String {
        var parts = [series.position?.shorthand ?? "Not started"]
        if let streamingService = series.streamingService {
            parts.append(streamingService)
        }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    WatchingView(library: try! Library.inMemory())
}
