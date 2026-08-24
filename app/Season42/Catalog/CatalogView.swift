import SwiftUI

/// The Catalog tab: what the shared Catalog offers, browsable with no network at all —
/// the app ships the snapshot it is filled from. Nothing here is the user's own data and
/// nothing here can be edited; the one thing the user can do with an entry is copy it
/// into their Library, which is what tapping through to it is for.
struct CatalogView: View {
    let catalog: Catalog
    /// Where a copied entry lands, and what knows whether an entry is already tracked.
    let library: Library
    /// Where a Sync the user asks for gets the Catalog from.
    let api: any CatalogFetching

    @State private var syncFailureMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if catalog.isEmpty {
                    ContentUnavailableView(
                        "No Catalog",
                        systemImage: "square.grid.2x2",
                        description: Text(
                            "This build could not load its Catalog snapshot. Sync to fetch "
                                + "the Catalog from the service."
                        )
                    )
                } else {
                    listing
                }
            }
            .navigationTitle("Catalog")
            .toolbar { syncButton }
            .failureAlert("Couldn't sync the Catalog", message: $syncFailureMessage)
        }
    }

    /// Fetches the Catalog afresh, saying so while it happens. Unlike the silent refresh
    /// a launch does, this one was asked for — so a failure is reported rather than
    /// swallowed, and either way what was cached is still there to browse.
    @ToolbarContentBuilder
    private var syncButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if catalog.isSyncing {
                ProgressView()
            } else {
                Button("Sync", systemImage: "arrow.clockwise") {
                    Task { await sync() }
                }
            }
        }
    }

    private func sync() async {
        do {
            try await catalog.sync(using: api)
        } catch {
            syncFailureMessage = error.localizedDescription
        }
    }

    private var listing: some View {
        List {
            Section("Series") {
                ForEach(catalog.series) { series in
                    NavigationLink {
                        CatalogSeriesView(series: series, library: library)
                    } label: {
                        CatalogRow(
                            title: series.title,
                            subtitle: series.seasonsSummary,
                            summary: series.summary,
                            isTracked: library.isTracked(series)
                        )
                    }
                }
            }
            Section("Popular movies") {
                ForEach(catalog.movies) { movie in
                    NavigationLink {
                        CatalogMovieView(movie: movie, library: library)
                    } label: {
                        CatalogRow(
                            title: movie.title,
                            subtitle: "Movie",
                            summary: movie.summary,
                            isTracked: library.isTracked(movie)
                        )
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
/// away. A row the user already tracks says so, so the same series isn't started twice.
private struct CatalogRow: View {
    let title: String
    let subtitle: String
    let summary: String
    let isTracked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                if isTracked {
                    Spacer(minLength: 8)
                    AlreadyTrackedMark()
                }
            }
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

/// How the Catalog says an entry is already in the user's Library.
private struct AlreadyTrackedMark: View {
    var body: some View {
        Label("In your Library", systemImage: "checkmark.circle.fill")
            .font(.caption)
            .foregroundStyle(.tint)
            .labelStyle(.titleAndIcon)
    }
}

/// A Catalog Series in full: what it is about, how long each season is, and the one
/// action the Catalog offers — copying it into the Library under a Status the user picks.
private struct CatalogSeriesView: View {
    let series: CatalogSeries
    let library: Library

    @Environment(\.dismiss) private var dismiss
    @State private var status: WatchStatus = .planned
    @State private var failureMessage: String?

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
            Section {
                if library.isTracked(series) {
                    AlreadyTrackedMark()
                }
                Picker("Status", selection: $status) {
                    ForEach(WatchStatus.allCases, id: \.self) { status in
                        Text(status.title).tag(status)
                    }
                }
                Button("Track this series", action: track)
            } header: {
                Text("Track")
            } footer: {
                trackingFootnote(
                    isTracked: library.isTracked(series),
                    otherwise: "Copies the series into your Library, with nothing watched yet."
                )
            }
        }
        .navigationTitle(series.title)
        .navigationBarTitleDisplayMode(.inline)
        .failureAlert("Couldn't track this", message: $failureMessage)
    }

    private func track() {
        do {
            try library.track(series, status: status)
            dismiss()
        } catch {
            failureMessage = error.localizedDescription
        }
    }
}

/// A Catalog Movie in full. There is no Status to pick: a copied movie starts unwatched,
/// which is to say on the user's watchlist.
private struct CatalogMovieView: View {
    let movie: CatalogMovie
    let library: Library

    @Environment(\.dismiss) private var dismiss
    @State private var failureMessage: String?

    var body: some View {
        List {
            Section {
                Text(movie.summary)
            }
            Section {
                if library.isTracked(movie) {
                    AlreadyTrackedMark()
                }
                Button("Track this movie", action: track)
            } footer: {
                trackingFootnote(
                    isTracked: library.isTracked(movie),
                    otherwise: "Copies the movie into your Library, unwatched."
                )
            }
        }
        .navigationTitle(movie.title)
        .navigationBarTitleDisplayMode(.inline)
        .failureAlert("Couldn't track this", message: $failureMessage)
    }

    private func track() {
        do {
            try library.track(movie)
            dismiss()
        } catch {
            failureMessage = error.localizedDescription
        }
    }
}

/// What the Track section says under its button: what tracking this entry would do, or
/// that the Library already holds one of it. The copy is the user's own from the moment
/// it exists (ADR-0002), so a second one is theirs to want — the mark is a warning, not
/// a refusal.
private func trackingFootnote(isTracked: Bool, otherwise whatItDoes: String) -> Text {
    Text(
        isTracked
            ? "Already in your Library. Tracking it again adds a second copy."
            : whatItDoes
    )
}

private extension View {
    /// Shows whatever went wrong verbatim — whatever the Library refused a copy for, the
    /// same bargain the hand-entry forms strike with it, or why a Sync the user asked for
    /// didn't happen.
    func failureAlert(_ title: String, message: Binding<String?>) -> some View {
        alert(
            title,
            isPresented: .init(
                get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } }
            ),
            presenting: message.wrappedValue
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { text in
            Text(text)
        }
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
    return CatalogView(catalog: catalog, library: try! Library.inMemory(), api: CatalogApi())
}
