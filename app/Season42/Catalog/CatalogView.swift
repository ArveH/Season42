import SwiftUI

/// The Catalog tab: what the shared Catalog offers, browsable with no network at all —
/// the app ships the snapshot it is filled from. Nothing here is the user's own data and
/// nothing here can be edited; tracking an entry arrives in a later ticket.
struct CatalogView: View {
    let catalog: Catalog

    var body: some View {
        NavigationStack {
            Group {
                if catalog.isEmpty {
                    ContentUnavailableView(
                        "No Catalog",
                        systemImage: "square.grid.2x2",
                        description: Text("This build could not load its Catalog snapshot.")
                    )
                } else {
                    listing
                }
            }
            .navigationTitle("Catalog")
        }
    }

    private var listing: some View {
        List {
            Section("Series") {
                ForEach(catalog.series) { series in
                    NavigationLink {
                        CatalogSeriesView(series: series)
                    } label: {
                        CatalogRow(
                            title: series.title,
                            subtitle: series.seasonsSummary,
                            summary: series.summary
                        )
                    }
                }
            }
            Section("Popular movies") {
                ForEach(catalog.movies) { movie in
                    NavigationLink {
                        CatalogMovieView(movie: movie)
                    } label: {
                        CatalogRow(title: movie.title, subtitle: "Movie", summary: movie.summary)
                    }
                }
            }
            Section("Streaming services") {
                // A service is a name and nothing else — that is all the Catalog serves
                // of one, and all a Tracked Series records.
                ForEach(catalog.streamingServices) { service in
                    Text(service.name)
                }
            }
        }
    }
}

/// One thing the Catalog offers: what it is called, how much of it there is, and the
/// opening of what it is about — enough to browse by, with the whole description a tap
/// away.
private struct CatalogRow: View {
    let title: String
    let subtitle: String
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }
}

/// A Catalog Series in full: what it is about, and how long each season is — the two
/// things someone deciding whether to track it wants.
private struct CatalogSeriesView: View {
    let series: CatalogSeries

    var body: some View {
        List {
            Section {
                Text(series.summary)
            }
            Section("Seasons") {
                ForEach(series.seasons.seasonNumbers, id: \.self) { season in
                    LabeledContent("Season \(season)", value: episodePhrase(series.seasons[season]))
                }
            }
        }
        .navigationTitle(series.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CatalogMovieView: View {
    let movie: CatalogMovie

    var body: some View {
        List {
            Section {
                Text(movie.summary)
            }
        }
        .navigationTitle(movie.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension CatalogSeries {
    /// How much there is of the series, as a row says it.
    var seasonsSummary: String {
        "\(seasonPhrase(seasons.count)) · \(episodePhrase(seasons.totalEpisodes))"
    }
}

private func seasonPhrase(_ count: Int) -> String {
    count == 1 ? "1 season" : "\(count) seasons"
}

private func episodePhrase(_ count: Int) -> String {
    count == 1 ? "1 episode" : "\(count) episodes"
}

#Preview {
    let catalog = try! Catalog.inMemory()
    try? catalog.fillFromBundledSnapshotIfEmpty()
    return CatalogView(catalog: catalog)
}
