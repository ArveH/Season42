import SwiftUI

/// What tapping a match pushes: the series' name, what it is called where it was made, what it
/// is about, and the seasons it has. Back returns to the results, so trying a second match is
/// one tap rather than a fresh search.
///
/// Nothing here is copied into the form and no poster is shown: this is a screen for telling
/// two similar titles apart, and reading what the next thing will fill in.
///
/// Every rule about the fetch is `SeriesDetailsRequest`'s. This renders what it says.
struct SeriesDetailsView: View {
    @State private var request: SeriesDetailsRequest

    /// - Parameters:
    ///   - match: the match that was tapped. Its name is on screen from the first frame.
    ///   - series: where the details are fetched from.
    init(for match: SeriesMatch, series: any SeriesSearching) {
        _request = State(initialValue: SeriesDetailsRequest(for: match, series: series))
    }

    var body: some View {
        Form {
            switch request.state {
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
        .navigationTitle(request.match.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await request.load() }
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

    /// The failure, said here rather than in an alert, and with the Retry that is the only
    /// thing there is to do about it: the match was served moments ago, so there is nothing
    /// for the user to correct. Back is the other way out, and the results are still there.
    private var failedSection: some View {
        Section {
            Label(
                "Couldn't load the details. The search results are still there — go back and pick another, or enter the series yourself.",
                systemImage: "exclamationmark.triangle"
            )
            .foregroundStyle(.secondary)
            Button("Try Again") {
                Task { await request.load() }
            }
        }
    }

    /// The names and the overview. The original name sits under the name rather than beside
    /// it in the bar, because a title long enough to be worth telling apart is a title too
    /// long for a navigation bar to show twice.
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
    NavigationStack {
        SeriesDetailsView(for: SeriesMatch(id: 95396, name: "Severance"), series: PreviewDetails())
    }
}

#Preview("No seasons") {
    NavigationStack {
        SeriesDetailsView(
            for: SeriesMatch(id: 95396, name: "Severance"),
            series: PreviewDetails(seasons: [])
        )
    }
}

#Preview("Unreachable") {
    NavigationStack {
        SeriesDetailsView(
            for: SeriesMatch(id: 95396, name: "Severance"),
            series: PreviewDetails(fails: true)
        )
    }
}

/// A BFF for the previews above, so every state of the screen can be seen without one running.
/// Not behind `#if DEBUG`: a `#Preview` is compiled in every configuration, so what it calls
/// has to be too.
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
            id: id,
            name: "Severance",
            originalName: "Severance",
            overview: "Mark leads a team of office workers whose memories have been surgically divided, "
                + "so that what they know at work and what they know at home are two separate lives.",
            seasons: seasons
        )
    }
}
