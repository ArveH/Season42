import SwiftUI

/// The Library tab: everything the user tracks, and the one place new entries are created.
struct LibraryView: View {
    let library: Library

    @State private var isAddingSeries = false

    var body: some View {
        NavigationStack {
            Group {
                if library.trackedSeries.isEmpty {
                    ContentUnavailableView(
                        "Nothing tracked yet",
                        systemImage: "books.vertical",
                        description: Text("Add a series to start tracking it.")
                    )
                } else {
                    List(library.trackedSeries) { series in
                        TrackedSeriesRow(series: series)
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Series", systemImage: "plus") { isAddingSeries = true }
                }
            }
            .sheet(isPresented: $isAddingSeries) {
                AddTrackedSeriesView(library: library)
            }
        }
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

#Preview {
    LibraryView(library: try! Library.inMemory())
}
