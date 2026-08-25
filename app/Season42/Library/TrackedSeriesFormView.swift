import SwiftUI

/// Hand-enters a Tracked Series, or edits one already tracked — the fields and the rules
/// are the same either way, so it is one form. It only gathers values; every rule about
/// them lives in `Library`, and whatever it refuses is shown back to the user verbatim.
struct TrackedSeriesFormView: View {
    let library: Library
    /// The series being edited, or nil when the user is entering a new one.
    let editing: TrackedSeries?

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var summary: String
    @State private var seasons: Seasons
    @State private var status: WatchStatus
    @State private var hasPosition: Bool
    @State private var position: Position
    @State private var streamingService: StreamingService?
    @State private var hasNextEpisodeDate: Bool
    @State private var nextEpisodeDate: Date
    @State private var failureMessage: String?

    init(library: Library, editing series: TrackedSeries? = nil) {
        self.library = library
        self.editing = series
        _title = State(initialValue: series?.title ?? "")
        _summary = State(initialValue: series?.summary ?? "")
        _seasons = State(initialValue: series?.seasons ?? [10])
        _status = State(initialValue: series?.status ?? .planned)
        _hasPosition = State(initialValue: series?.position != nil)
        _position = State(initialValue: series?.position ?? Position(season: 1, episode: 1))
        _streamingService = State(initialValue: series?.streamingService)
        _hasNextEpisodeDate = State(initialValue: series?.nextEpisodeDate != nil)
        _nextEpisodeDate = State(initialValue: series?.nextEpisodeDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("Description", text: $summary, axis: .vertical)
                        .lineLimit(2...5)
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

                Section("Position") {
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
            // Keep the Position inside the seasons and episodes entered so far.
            .onChange(of: seasons) { _, _ in position = seasons.clamping(position) }
            .onChange(of: position.season) { _, _ in position = seasons.clamping(position) }
        }
    }

    private var isEditing: Bool { editing != nil }

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
