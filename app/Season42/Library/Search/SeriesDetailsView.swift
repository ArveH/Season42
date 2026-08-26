import SwiftUI

/// What tapping a match pushes: the series' poster, its name, what it is called where it was
/// made, what it is about, the seasons it has, and the Copy that fills the form in with them.
/// Back is the navigation bar's own, and the results are still listed underneath it, so trying
/// a second match is one tap rather than a fresh search.
///
/// Everything Copy would write is worked out before it is tapped, as a `SeriesCopy`, and
/// everything that copy invents is on the screen above the button — which is the whole of what
/// makes the seasons flatten honest (ADR-0011). This renders that; it decides none of it.
///
/// Every rule about reading the details is `SeriesSearch`'s — opening a match is the second
/// half of the search, not a thing of its own.
struct SeriesDetailsView: View {
    /// The match that was tapped. Its name is on screen from the first frame, before any
    /// details have arrived.
    let match: SeriesMatch

    /// The search this was pushed from, which is what reads the details and holds them.
    let search: SeriesSearch

    /// What the form was holding when the sheet opened, which is what a copy would land on top
    /// of. It cannot have moved since: the form is underneath a sheet.
    let form: SeriesFormContents

    /// Hands the copy to the form, which writes it in and closes the sheet. Nothing here
    /// dismisses anything: the form owns the sheet, so the form is what closes it.
    let onCopy: (SeriesCopy) -> Void

    /// The copy the user asked for over a form they had already typed into, held while they are
    /// asked whether they meant it. Nil the rest of the time.
    @State private var pendingCopy: SeriesCopy?

    /// How tall the poster is drawn, scaled with the text around it.
    @ScaledMetric(relativeTo: .body) private var posterHeight = 180

    var body: some View {
        Form {
            switch search.detailsState {
            case .loading:
                loadingSection

            case .loaded(let details):
                let copy = details.copy(over: form, poster: search.poster)
                posterSection
                aboutSection(details)
                seasonsSection(details.seasons)
                notesSection(copy.notes)
                copySection(copy)

            case .failed:
                failedSection
            }
        }
        // The match's name, so the bar says which one was tapped before anything has arrived
        // and doesn't change under the user once it has.
        .navigationTitle(match.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Replace what you've entered?",
            isPresented: .init(
                get: { pendingCopy != nil },
                set: { if !$0 { pendingCopy = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingCopy
        ) { copy in
            Button("Copy", role: .destructive) { onCopy(copy) }
            Button("Keep what I typed", role: .cancel) {}
        } message: { _ in
            Text(
                "The title, the description, the seasons and the poster on the form are replaced. "
                    + "Your status, streaming service, next episode date and what you have watched are left alone."
            )
        }
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

    /// The poster, or the stand-in where there is none to draw — TMDB has none, or the bytes
    /// would not come. A poster still on its way spins in the same frame rather than showing
    /// the stand-in, which would say "this series has no poster" about one that has.
    ///
    /// The bytes drawn here are the bytes Copy keeps: the poster is fetched once, so what the
    /// user looked at is what they end up with.
    @ViewBuilder
    private var posterSection: some View {
        Section {
            Group {
                if search.posterState == .loading {
                    ProgressView()
                        .frame(width: posterHeight * 2 / 3, height: posterHeight)
                } else {
                    Poster(poster: search.poster, height: posterHeight)
                        .accessibilityLabel(match.name)
                }
            }
            .frame(maxWidth: .infinity)
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

    /// What copying would do that TMDB's answer doesn't say — every season dropped, every one
    /// invented, and a Position that would move. Above the button and not behind it, because a
    /// count the app made up is only defensible while it is stated before it is taken (ADR-0011).
    /// Nothing at all where the answer needed nothing done to it.
    @ViewBuilder
    private func notesSection(_ notes: [SeriesCopyNote]) -> some View {
        if !notes.isEmpty {
            Section("Before you copy") {
                ForEach(notes) { note in
                    Label(note.text, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Copy, and what it would cost. A form the user has typed into is asked about first; a
    /// fresh one is simply filled in, because there is nothing there to lose.
    private func copySection(_ copy: SeriesCopy) -> some View {
        Section {
            Button("Copy into the form") {
                if copy.overwritesTheForm {
                    pendingCopy = copy
                } else {
                    onCopy(copy)
                }
            }
        } footer: {
            Text(
                "Fills in the title, the description, the seasons and the poster, and leaves the rest to you. "
                    + "Nothing is saved until you save the form."
            )
        }
    }
}

#Preview("Details") {
    PreviewDetailScreen(series: PreviewDetails())
}

#Preview("Over a form already filled in") {
    PreviewDetailScreen(
        series: PreviewDetails(),
        form: SeriesFormContents(
            title: "Severence",
            summary: "The one about the office.",
            seasons: [10, 10, 10, 10],
            position: Position(season: 4, episode: 2)
        )
    )
}

#Preview("Specials and a gap") {
    PreviewDetailScreen(
        series: PreviewDetails(seasons: [
            SeriesSeason(seasonNumber: 0, episodeCount: 3),
            SeriesSeason(seasonNumber: 1, episodeCount: 9),
            SeriesSeason(seasonNumber: 3, episodeCount: 10),
            SeriesSeason(seasonNumber: 4, episodeCount: 0),
        ])
    )
}

#Preview("No poster") {
    PreviewDetailScreen(series: PreviewDetails(hasPoster: false))
}

#Preview("A poster that won't fetch") {
    PreviewDetailScreen(series: PreviewDetails(posterFails: true))
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
    var form: SeriesFormContents = .new

    private var match: SeriesMatch { SeriesMatch(id: 95396, name: "Severance") }

    var body: some View {
        NavigationStack {
            SeriesDetailsView(
                match: match,
                search: SeriesSearch(text: match.name, series: series),
                form: form,
                onCopy: { _ in }
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
    var hasPoster = true
    var posterFails = false

    func series(matching text: String) async throws -> [SeriesMatch] { [] }

    func details(for id: Int) async throws -> SeriesDetails {
        if fails { throw BffError.notServed(status: 502) }
        return SeriesDetails(
            name: "Severance",
            originalName: "Severance",
            overview: "Mark leads a team of office workers whose memories have been surgically divided, "
                + "so that what they know at work and what they know at home are two separate lives.",
            hasPoster: hasPoster,
            seasons: seasons
        )
    }

    func poster(for id: Int) async throws -> Data {
        if posterFails { throw BffError.notServed(status: 502) }
        return PreviewPoster.bytes(.systemIndigo)
    }
}
