import SwiftUI

/// The sheet the Search button beside the Title opens: a search box, and the names the BFF
/// matched. A sheet over the form rather than a push into it, because the form is itself a
/// sheet with Cancel and Save in its bar, and two competing ways out in one bar is the thing
/// to avoid.
///
/// Every rule about the search is `SeriesSearch`'s. This renders what it says, and writes
/// nothing back to the form it was opened over — the box it opened pre-filled from is a copy
/// of the Title, not the Title.
struct SeriesSearchSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var search: SeriesSearch

    /// - Parameters:
    ///   - title: what the form's Title held when Search was tapped, which is what the box
    ///     opens holding. Empty is an ordinary case: the box is simply ready to type in.
    ///   - matches: where the search gets its answers.
    init(searchingFor title: String, matches: any SeriesSearching) {
        _search = State(initialValue: SeriesSearch(text: title, series: matches))
    }

    var body: some View {
        NavigationStack {
            Form {
                searchSection
                resultsSection
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
                // Plain rows: tapping one opens its details, and there are no details yet.
                ForEach(matches) { match in
                    Text(match.name)
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
    SeriesSearchSheet(searchingFor: "sever", matches: PreviewSeries())
}

#Preview("From an empty title") {
    SeriesSearchSheet(searchingFor: "", matches: PreviewSeries())
}

#Preview("Nothing matched") {
    SeriesSearchSheet(searchingFor: "zzz", matches: PreviewSeries(matches: []))
}

#Preview("Unreachable") {
    SeriesSearchSheet(searchingFor: "sever", matches: PreviewSeries(fails: true))
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

    func series(matching text: String) async throws -> [SeriesMatch] {
        if fails { throw BffError.notServed(status: 502) }
        return matches
    }
}
