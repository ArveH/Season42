import SwiftUI

/// Hand-enters a Tracked Series, or edits one already tracked — the fields and the rules
/// are the same either way, so it is one form. It only gathers values; every rule about
/// them lives in `Library`, and whatever it refuses is shown back to the user verbatim.
struct TrackedSeriesFormView: View {
    let library: Library
    /// The series being edited, or nil when the user is entering a new one.
    let editing: TrackedSeries?

    /// Where the search sheet gets its answers. The default is the live BFF, so the form
    /// gets the search without knowing there is a network.
    let series: any SeriesSearching

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var summary: String
    @State private var poster: Data?
    @State private var seasons: Seasons
    @State private var status: WatchStatus
    @State private var hasPosition: Bool
    @State private var position: Position
    @State private var streamingService: StreamingService?
    @State private var hasNextEpisodeDate: Bool
    @State private var nextEpisodeDate: Date
    @State private var failureMessage: String?
    @State private var isSearching = false

    /// How tall the adopted Poster is drawn, scaled with the text beside it.
    @ScaledMetric(relativeTo: .body) private var posterHeight = 120

    /// Where a copy moved the Position, once one has. The detail screen said it would before
    /// Copy was tapped; this is the form saying it did, because the sheet the user read it on
    /// is gone by the time it happens. Nil until a copy moves one.
    @State private var positionMovedTo: Position?

    init(
        library: Library,
        editing tracked: TrackedSeries? = nil,
        series: any SeriesSearching = BffClient()
    ) {
        self.library = library
        self.editing = tracked
        self.series = series
        _title = State(initialValue: tracked?.title ?? "")
        _summary = State(initialValue: tracked?.summary ?? "")
        _poster = State(initialValue: tracked?.poster)
        _seasons = State(initialValue: tracked?.seasons ?? .newSeriesPlaceholder)
        _status = State(initialValue: tracked?.status ?? .planned)
        _hasPosition = State(initialValue: tracked?.position != nil)
        _position = State(initialValue: tracked?.position ?? Position(season: 1, episode: 1))
        _streamingService = State(initialValue: tracked?.streamingService)
        _hasNextEpisodeDate = State(initialValue: tracked?.nextEpisodeDate != nil)
        _nextEpisodeDate = State(initialValue: tracked?.nextEpisodeDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Searching is for what is typed, so the Title and the Search button
                    // that looks it up belong on one row.
                    HStack {
                        TextField("Title", text: $title)
                        Button("Search", systemImage: "magnifyingglass") { isSearching = true }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                    }
                    TextField("Description", text: $summary, axis: .vertical)
                        .lineLimit(2...5)
                }

                if poster != nil {
                    posterSection
                }

                Section("Seasons") {
                    Stepper("^[\(seasons.count) season](inflect: true)", value: seasonCount, in: 1...50)
                    ForEach(1...seasons.count, id: \.self) { season in
                        Stepper(
                            "Season \(season): ^[\(seasons[season]) episode](inflect: true)",
                            value: $seasons[season],
                            in: 1...200
                        )
                    }
                }

                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(WatchStatus.allCases, id: \.self) { status in
                            Text(status.title).tag(status)
                        }
                    }
                }

                Section {
                    Toggle("Already watched some", isOn: $hasPosition)
                    if hasPosition {
                        Picker("Season", selection: $position.season) {
                            ForEach(1...seasons.count, id: \.self) { season in
                                Text("Season \(season)").tag(season)
                            }
                        }
                        Picker("Episode", selection: $position.episode) {
                            ForEach(1...episodesInSelectedSeason, id: \.self) { episode in
                                Text("Episode \(episode)").tag(episode)
                            }
                        }
                    }
                } header: {
                    Text("Position")
                } footer: {
                    if let positionMovedTo {
                        Text("Copying moved your position to \(positionMovedTo.shorthand) — the copied seasons don't reach where it was.")
                    }
                }

                Section("Where and when") {
                    StreamingServicePicker(library: library, selection: $streamingService)
                    Toggle("Next episode date", isOn: $hasNextEpisodeDate)
                    if hasNextEpisodeDate {
                        DatePicker(
                            "Next episode",
                            selection: $nextEpisodeDate,
                            displayedComponents: .date
                        )
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Series" : "Track a Series")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add", action: submit)
                }
            }
            .alert(
                isEditing ? "Couldn't save the series" : "Couldn't add the series",
                isPresented: .init(
                    get: { failureMessage != nil },
                    set: { if !$0 { failureMessage = nil } }
                ),
                presenting: failureMessage
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
            // The sheet opens over what the form holds and writes back nothing but a copy the
            // user asked for: what they do in there costs them the form only when they choose
            // to take something from it.
            .sheet(isPresented: $isSearching) {
                SeriesSearchSheet(over: contents, series: series, onCopy: apply)
            }
            // Keep the Position inside the seasons and episodes entered so far.
            .onChange(of: seasons) { _, _ in position = seasons.clamping(position) }
            .onChange(of: position.season) { _, _ in position = seasons.clamping(position) }
        }
    }

    /// The Poster in force, and the only way to be rid of one copied by mistake. Shown only
    /// where there is one — there is nothing else to put in the section — and Remove takes the
    /// Poster and nothing else with it, so a wrong copy is not a reason to lose the rest of
    /// the form. The bytes are the entry's own, so this draws with no BFF anywhere.
    private var posterSection: some View {
        Section("Poster") {
            HStack {
                PosterImage(poster: poster, height: posterHeight)
                Spacer()
                Button("Remove", role: .destructive) { poster = nil }
                    .buttonStyle(.borderless)
            }
        }
    }

    private var isEditing: Bool { editing != nil }

    /// What the form is holding, for the search sheet to work out what a copy would land on
    /// top of. The Position is what the user says they have watched to, and nothing at all
    /// while they say they have watched nothing.
    private var contents: SeriesFormContents {
        SeriesFormContents(
            title: title,
            summary: summary,
            seasons: seasons,
            position: hasPosition ? position : nil
        )
    }

    /// Takes what the user copied off a Series Details and closes the sheet. Everything copied
    /// is theirs from here — as editable as if they had typed it, and saved no sooner.
    ///
    /// Only the fields TMDB's answer speaks to are written — the Poster among them, as the very
    /// bytes the detail screen drew, and as nothing where that series had none: a copy replaces
    /// what the last one left, rather than leaving one series' picture over another's name. The Status, the Streaming
    /// Service, the Next Episode Date and the watched state are untouched; the Position moves
    /// only where the copied seasons no longer reach it, which the clamp on `seasons` above
    /// does and the detail screen said it would. That move is stated here too: the screen that
    /// warned of it is gone by the time it happens.
    private func apply(_ copied: SeriesCopy) {
        title = copied.title
        summary = copied.summary
        poster = copied.poster
        seasons = copied.seasons
        positionMovedTo = hasPosition ? copied.movedPosition : nil
        isSearching = false
    }

    private var seasonCount: Binding<Int> {
        Binding(get: { seasons.count }, set: { seasons.setCount($0) })
    }

    /// Never zero, so the episode picker always has a range to show while the user is
    /// mid-edit and the Position has not been clamped yet.
    private var episodesInSelectedSeason: Int {
        max(1, seasons.episodeCount(inSeason: position.season) ?? 1)
    }

    private func submit() {
        do {
            if let editing {
                try library.updateTrackedSeries(
                    editing,
                    title: title,
                    summary: summary,
                    poster: poster,
                    seasons: seasons,
                    status: status,
                    position: hasPosition ? position : nil,
                    streamingService: streamingService,
                    nextEpisodeDate: hasNextEpisodeDate ? nextEpisodeDate : nil
                )
            } else {
                try library.addTrackedSeries(
                    title: title,
                    summary: summary,
                    poster: poster,
                    seasons: seasons,
                    status: status,
                    position: hasPosition ? position : nil,
                    streamingService: streamingService,
                    nextEpisodeDate: hasNextEpisodeDate ? nextEpisodeDate : nil
                )
            }
            dismiss()
        } catch {
            failureMessage = error.localizedDescription
        }
    }
}

#Preview {
    TrackedSeriesFormView(library: try! Library.inMemory())
}
