import SwiftUI

/// The Watching tab: the series the user is actively into, most recently watched first,
/// each one tap away from its next episode, with the ones they're waiting to come back
/// listed below. Every rule about order and about what a tap does lives in `Library`;
/// this view only names things and calls it.
struct WatchingView: View {
    let library: Library

    var body: some View {
        NavigationStack {
            Group {
                if library.watching.isEmpty && library.waiting.isEmpty {
                    ContentUnavailableView(
                        "Nothing on the go",
                        systemImage: "play.circle",
                        description: Text("Series you set to Watching or Waiting show up here.")
                    )
                } else {
                    List {
                        if !library.watching.isEmpty {
                            Section {
                                ForEach(library.watching) { series in
                                    WatchingRow(library: library, series: series)
                                }
                            }
                        }
                        if !library.waiting.isEmpty {
                            Section("Waiting") {
                                ForEach(library.waiting) { series in
                                    WaitingRow(series: series)
                                }
                            }
                        }
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
            Text(series.positionAndService)
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

}

/// A series the user is waiting to come back: where they got to, and when the next
/// episode lands if they've recorded it. There is nothing to tap until it's back.
private struct WaitingRow: View {
    let series: TrackedSeries

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(series.title)
                .font(.headline)
            Text(series.positionAndService)
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
}

private extension TrackedSeries {
    /// Where the user got to, and where they watch it when they've said.
    var positionAndService: String {
        var parts = [position?.shorthand ?? "Not started"]
        if let streamingService {
            parts.append(streamingService)
        }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    WatchingView(library: try! Library.inMemory())
}
