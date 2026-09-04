import SwiftUI

/// The sheet the Search button beside the Title opens: a search box, and the names the BFF
/// matched. A sheet over the form rather than a push into it, because the form is itself a
/// sheet with Cancel and Save in its bar, and two competing ways out in one bar is the thing
/// to avoid.
///
/// Every rule about the search is `SeriesSearch`'s. This renders what it says, and writes
/// nothing back to the form it was opened over — the box it opened pre-filled from is a copy
/// of the Title, not the Title. The one thing that ever reaches the form is a copy the user
/// asked for on the detail screen, and it goes there by way of `onCopy`.
///
/// Tapping a match pushes its details onto the sheet's own stack, so Back comes straight back
/// to the results the search already has: trying a second match is one tap, not a second
/// search.
struct SeriesSearchSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var search: SeriesSearch

    /// What the form was holding when Search was tapped — the Title the box opens with, and
    /// the rest of what a copy would land on top of.
    private let form: SeriesFormContents

    /// What to do with a copy the user asked for. The form writes it in and closes this sheet:
    /// the form owns the sheet, so the form is what closes it.
    private let onCopy: (SeriesCopy) -> Void

    /// - Parameters:
    ///   - form: what the form holds. Its Title is what the box opens holding, and an empty one
    ///     is an ordinary case: the box is simply ready to type in.
    ///   - series: where the search gets its answers.
    ///   - onCopy: what to do with what the user copied.
    init(
        over form: SeriesFormContents,
        series: any SeriesSearching,
        onCopy: @escaping (SeriesCopy) -> Void
    ) {
        self.form = form
        self.onCopy = onCopy
        _search = State(initialValue: SeriesSearch(text: form.title, series: series))
    }

    var body: some View {
        NavigationStack {
            Form {
                searchSection
                resultsSection
                TmdbAttribution()
            }
            .navigationDestination(for: SeriesMatch.self) { match in
                SeriesDetailsView(match: match, search: search, form: form, onCopy: onCopy)
            }
            .navigationTitle("Find a series")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            // Tapping Search with a Title already typed means searching for it, so the sheet
            // arrives with the answer already on its way. An empty Title searches for nothing
            // and this costs nothing: what opens is an empty box.
            .task { await search.search() }
        }
    }

    /// The text being searched for, and the button that searches for it again after it has
    /// been corrected.
    private var searchSection: some View {
        Section {
            HStack {
                TextField("Series title", text: $search.text)
                    .submitLabel(.search)
                    .onSubmit { runSearch() }
                Button("Search", systemImage: "magnifyingglass") { runSearch() }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
            }
        } footer: {
            Text("Correcting this doesn't change the title on the form.")
        }
    }

    /// What the search has to say. A failure is said here rather than in an alert: the alerts
    /// around the form are for what `Library` refuses, and a BFF that isn't there refuses
    /// nothing — the user can close this and type the series in by hand.
    @ViewBuilder
    private var resultsSection: some View {
        switch search.state {
        case .idle:
            EmptyView()

        case .searching:
            Section {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Searching…")
                        .foregroundStyle(.secondary)
                }
            }

        case .results(let matches):
            Section("Matches") {
                // The match itself is what the row is pushed with: there is nothing to look
                // up again on the way to its details, and the name is on screen from the
                // first frame of the screen it pushes.
                ForEach(matches) { match in
                    NavigationLink(match.name, value: match)
                }
            }

        case .matchedNothing:
            Section {
                Text("Nothing matched that title. Try another spelling, or close this and enter it yourself.")
                    .foregroundStyle(.secondary)
            }

        case .failed:
            Section {
                Label(
                    "Couldn't reach the search service. You can still enter the series yourself.",
                    systemImage: "exclamationmark.triangle"
                )
                .foregroundStyle(.secondary)
            }
        }
    }

    private func runSearch() {
        Task { await search.search() }
    }
}

#Preview("Matches") {
    SeriesSearchSheet(over: .searching(for: "sever"), series: PreviewSeries()) { _ in }
}

#Preview("From an empty title") {
    SeriesSearchSheet(over: .new, series: PreviewSeries()) { _ in }
}

#Preview("Nothing matched") {
    SeriesSearchSheet(over: .searching(for: "zzz"), series: PreviewSeries(matches: [])) { _ in }
}

#Preview("Unreachable") {
    SeriesSearchSheet(over: .searching(for: "sever"), series: PreviewSeries(fails: true)) { _ in }
}

private extension SeriesFormContents {
    /// A new form with only a Title typed into it, for the previews above.
    static func searching(for title: String) -> SeriesFormContents {
        var form = SeriesFormContents.new
        form.title = title
        return form
    }
}

/// A BFF for the previews above, so every state of the search can be seen without one
/// running. Not behind `#if DEBUG`: a `#Preview` is compiled in every configuration, so what
/// it calls has to be too.
private struct PreviewSeries: SeriesSearching {
    var matches: [SeriesMatch] = [
        SeriesMatch(id: 95396, name: "Severance"),
        SeriesMatch(id: 1399, name: "Game of Thrones"),
    ]
    var fails = false

    var details = SeriesDetails(
        name: "Severance",
        originalName: "Severance",
        overview: "Mark leads a team of office workers whose memories have been surgically divided.",
        hasPoster: true,
        seasons: [
            SeriesSeason(seasonNumber: 0, episodeCount: 3),
            SeriesSeason(seasonNumber: 1, episodeCount: 9),
            SeriesSeason(seasonNumber: 2, episodeCount: 10),
        ]
    )

    func series(matching text: String) async throws -> [SeriesMatch] {
        if fails { throw BffError.notServed(status: 502) }
        return matches
    }

    func seriesDetails(for id: Int) async throws -> SeriesDetails {
        if fails { throw BffError.notServed(status: 502) }
        return details
    }

    func seriesPoster(for id: Int) async throws -> Data {
        if fails { throw BffError.notServed(status: 502) }
        return PreviewPoster.bytes(.systemIndigo)
    }
}
