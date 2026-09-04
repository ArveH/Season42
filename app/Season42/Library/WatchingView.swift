import SwiftUI

/// The Watching tab: the series the user is actively into, in the Watching Order they
/// picked, each one tap away from its next episode, with the ones they're waiting to come
/// back listed below. Every rule about what a tap does lives in `Library` and every rule
/// about the order in `WatchingListing`; this view only names things and calls them.
///
/// Every row also opens the same form the Library tab opens for its series, so the user
/// never goes to the Library tab to find a series they are already looking at.
struct WatchingView: View {
    let library: Library
    @State private var listing: WatchingListing
    /// The series whose form is up, or nil when none is.
    @State private var editing: TrackedSeries?

    init(library: Library) {
        self.library = library
        _listing = State(initialValue: WatchingListing(library: library))
    }

    var body: some View {
        NavigationStack {
            Group {
                if listing.series.isEmpty && library.waiting.isEmpty {
                    ContentUnavailableView(
                        "Nothing on the go",
                        systemImage: "play.circle",
                        description: Text("Series you set to Watching or Waiting show up here.")
                    )
                } else {
                    List {
                        if !listing.series.isEmpty {
                            Section {
                                ForEach(listing.series) { series in
                                    WatchingRow(library: library, series: series) {
                                        editing = series
                                    }
                                }
                            } header: {
                                orderPicker
                            }
                        }
                        if !library.waiting.isEmpty {
                            Section("Waiting") {
                                ForEach(library.waiting) { series in
                                    WaitingRow(series: series) { editing = series }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Watching")
            .sheet(item: $editing) { series in
                TrackedSeriesFormView(library: library, editing: series)
            }
        }
    }

    /// The two Watching Orders side by side, so the one in force is readable without
    /// tapping anything (ADR-0014). Heads the Watching section and not the list, because
    /// it says nothing about the Waiting listing below it.
    private var orderPicker: some View {
        Picker("Order", selection: $listing.order) {
            ForEach(WatchingOrder.allCases, id: \.self) { order in
                Text(order.label).tag(order)
            }
        }
        .pickerStyle(.segmented)
        .textCase(nil)
        .padding(.bottom, 8)
    }
}

/// A series the user is watching: where they got to, when the next episode lands if
/// they've recorded it, and what they can do about it — mark the next episode watched, or
/// say where the series stands once there is no next episode, take a watch back, and edit
/// the series.
private struct WatchingRow: View {
    let library: Library
    let series: TrackedSeries
    let edit: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Only what the row says goes beside the Poster. What it offers spans the row
            // under both, so the buttons keep the width they had before there was a
            // thumbnail — at the largest text sizes they need every point of it.
            PosterRow(poster: series.poster) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(series.title)
                        .font(.headline)
                    StreamingServiceSegment(subtitle: series.positionSoFar, service: series.streamingService)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    NextEpisodeDateLine(date: series.nextEpisodeDate)
                }
            }

            actions {
                if series.isAtLastKnownEpisode {
                    endOfSeriesQuestion
                } else if let nextEpisode = series.nextEpisode {
                    Button("Mark \(nextEpisode.shorthand) watched") {
                        library.markNextEpisodeWatched(series)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if series.position != nil {
                    Button("Un-watch", systemImage: "arrow.uturn.backward") {
                        library.unwatchLastEpisode(series)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                }

                EditSeriesButton(edit: edit)
            }
        }
        .padding(.vertical, 4)
    }

    /// Shown in place of the "watched it" button once the Position is at the last episode
    /// the user has entered: the only ways on are out of the Watching list.
    private var endOfSeriesQuestion: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Finished the series, or waiting for more?")
                .font(.subheadline)
            actions {
                Button("Finished") { library.setStatus(.finished, on: series) }
                Button("Waiting") { library.setStatus(.waiting, on: series) }
            }
            .buttonStyle(.bordered)
        }
    }

    /// The row's buttons side by side, until the text is an accessibility size — then one
    /// under the other, because side by side they would squeeze each other's labels into a
    /// column of single letters and nothing would be usable.
    private func actions<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading))
            : AnyLayout(HStackLayout())
        return layout { content() }
    }
}

/// A series the user is waiting to come back: where they got to, and when the next
/// episode lands if they've recorded it. Nothing to mark watched until it's back, but
/// the row can be edited — which is exactly where a wrong Next Episode Date gets noticed.
private struct WaitingRow: View {
    let series: TrackedSeries
    let edit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PosterRow(poster: series.poster) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(series.title)
                        .font(.headline)
                    StreamingServiceSegment(subtitle: series.positionSoFar, service: series.streamingService)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    NextEpisodeDateLine(date: series.nextEpisodeDate)
                }
            }

            EditSeriesButton(edit: edit)
        }
        .padding(.vertical, 4)
    }
}

/// The pencil that opens the series' form, the same on both kinds of row. Icon-only so it
/// keeps its width at the largest text sizes, where a Watching row's buttons need every
/// point of it; the label is still read out.
private struct EditSeriesButton: View {
    let edit: () -> Void

    var body: some View {
        Button("Edit", systemImage: "pencil", action: edit)
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
    }
}

private extension TrackedSeries {
    /// Where the user got to. Where they watch it is `StreamingServiceSegment`'s to draw.
    var positionSoFar: String {
        position?.shorthand ?? "Not started"
    }
}

#Preview {
    WatchingView(library: try! Library.inMemory())
}
