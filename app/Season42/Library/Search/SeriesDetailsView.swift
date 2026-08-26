import SwiftUI

/// What tapping a match pushes: the series' name, what it is called where it was made, what it
/// is about, and the seasons it has. Back is the navigation bar's own, and the results are
/// still listed underneath it, so trying a second match is one tap rather than a fresh search.
///
/// Nothing here is copied into the form and no poster is shown: this is a screen for telling
/// two similar titles apart, and reading what the next thing will fill in.
///
/// Every rule about reading the details is `SeriesSearch`'s — opening a match is the second
/// half of the search, not a thing of its own. This renders what it says.
struct SeriesDetailsView: View {
    /// The match that was tapped. Its name is on screen from the first frame, before any
    /// details have arrived.
    let match: SeriesMatch

    /// The search this was pushed from, which is what reads the details and holds them.
    let search: SeriesSearch

    var body: some View {
        Form {
            switch search.detailsState {
            case .loading:
                loadingSection

            case .loaded(let details):
                aboutSection(details)
                seasonsSection(details.seasons)

            case .failed:
                failedSection
            }
        }
        // The match's name, so the bar says which one was tapped before anything has arrived
        // and doesn't change under the user once it has.
        .navigationTitle(match.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await search.open(match) }
    }

    private var loadingSection: some View {
        Section {
            HStack(spacing: 12) {
                ProgressView()
                Text("Loading details…")
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The failure, said here rather than in an alert: the alerts around the form are for what
    /// `Library` refuses, and a BFF that isn't there refuses nothing. Back is what to do about
    /// it, and it costs nothing — the results it returns to are still listed.
    private var failedSection: some View {
        Section {
            Label(
                "Couldn't load the details. Go back and pick another match, or close this and enter the series yourself.",
                systemImage: "exclamationmark.triangle"
            )
            .foregroundStyle(.secondary)
        }
    }

    /// The names and the overview. The original name sits under the name rather than beside it
    /// in the bar, because a title long enough to be worth telling apart is a title too long
    /// for a navigation bar to show twice.
    private func aboutSection(_ details: SeriesDetails) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(details.name)
                    .font(.headline)
                if !details.originalName.isEmpty {
                    Text(details.originalName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if !details.overview.isEmpty {
                Text(details.overview)
            }
        }
    }

    /// Every season TMDB lists, with its episode count. Season 0 is TMDB's specials, and what
    /// to call it is the app's decision to make — the BFF passes the number through and says
    /// nothing about it.
    @ViewBuilder
    private func seasonsSection(_ seasons: [SeriesSeason]) -> some View {
        Section("Seasons") {
            if seasons.isEmpty {
                Text("TMDB lists no seasons for this series.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(seasons) { season in
                    LabeledContent {
                        Text("^[\(season.episodeCount) episode](inflect: true)")
                    } label: {
                        if season.seasonNumber == 0 {
                            Text("Specials")
                        } else {
                            Text("Season \(season.seasonNumber)")
                        }
                    }
                }
            }
        }
    }
}

#Preview("Details") {
    PreviewDetailScreen(series: PreviewDetails())
}

#Preview("No seasons") {
    PreviewDetailScreen(series: PreviewDetails(seasons: []))
}

#Preview("Unreachable") {
    PreviewDetailScreen(series: PreviewDetails(fails: true))
}

/// The detail screen as the sheet pushes it — over a search, because the search is what reads
/// the details. Not behind `#if DEBUG`: a `#Preview` is compiled in every configuration, so
/// what it calls has to be too.
private struct PreviewDetailScreen: View {
    let series: any SeriesSearching

    private var match: SeriesMatch { SeriesMatch(id: 95396, name: "Severance") }

    var body: some View {
        NavigationStack {
            SeriesDetailsView(
                match: match,
                search: SeriesSearch(text: match.name, series: series)
            )
        }
    }
}

/// A BFF for the previews above, so every state of the screen can be seen without one running.
private struct PreviewDetails: SeriesSearching {
    var seasons: [SeriesSeason] = [
        SeriesSeason(seasonNumber: 0, episodeCount: 3),
        SeriesSeason(seasonNumber: 1, episodeCount: 9),
        SeriesSeason(seasonNumber: 2, episodeCount: 10),
    ]
    var fails = false

    func series(matching text: String) async throws -> [SeriesMatch] { [] }

    func details(for id: Int) async throws -> SeriesDetails {
        if fails { throw BffError.notServed(status: 502) }
        return SeriesDetails(
            name: "Severance",
            originalName: "Severance",
            overview: "Mark leads a team of office workers whose memories have been surgically divided, "
                + "so that what they know at work and what they know at home are two separate lives.",
            seasons: seasons
        )
    }
}
