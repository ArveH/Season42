import SwiftUI

/// The Watch App's one screen: the Watching listing in the Watching Order the user picked on
/// the phone, and the Waiting listing below it. Every rule about the order lives in
/// `WatchingListing`, as on the phone; this view names things and draws them.
///
/// A Watching row marks the next episode watched and, by a swipe, takes the last one back,
/// through the same `Library` operations as the phone's row, so both stamp Watched At the
/// same way (ADR-0014). Neither moves a row: the listing is held still until the next
/// re-take, as on the phone. A series whose Status was changed on the phone is held where it
/// is too, drawn as it was and offering nothing, until the next re-take sweeps it — never
/// as a Lapsed Row (see Watch App in GLOSSARY.md).
struct WatchingListView: View {
    let library: Library
    @State private var listing: WatchingListing
    @State private var iCloud = ICloudAccount()
    @Environment(\.scenePhase) private var scenePhase

    init(library: Library) {
        self.library = library
        _listing = State(
            initialValue: WatchingListing(
                library: library,
                orderStore: ICloudWatchingOrderStore()
            )
        )
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Watching")
        }
        // The listing is re-taken when the app launches and whenever it comes to the front,
        // and held still otherwise. There is no picker here, so each re-take also takes up
        // the order last picked on the phone.
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            listing.retakeInStoredOrder()
            Task { await iCloud.check() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if iCloud.isUnavailable {
            ContentUnavailableView(
                "No iCloud",
                systemImage: "icloud.slash",
                description: Text(
                    "Season42 lists your Library from iCloud. Sign in to iCloud on this "
                        + "Apple Watch to see it here."
                )
            )
        } else if listing.isEmpty {
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
                            // Its Status was changed on the phone since the re-take, so it
                            // is drawn as it was and offers nothing to tap until the next
                            // re-take sweeps it.
                            if listing.isLapsed(series) {
                                SeriesRow(series: series)
                            } else {
                                WatchingRow(library: library, series: series)
                            }
                        }
                    }
                }
                if !listing.waiting.isEmpty {
                    Section("Waiting") {
                        ForEach(listing.waiting) { SeriesRow(series: $0) }
                    }
                }
            }
        }
    }
}

/// A series the user is watching, and what the Watch App lets them do about it: mark the
/// next episode watched, or swipe to take the last one back. The same rules as the phone's
/// Watching row — once the Position is at the last known episode there is nothing to mark,
/// and with no Position there is nothing to take back.
private struct WatchingRow: View {
    let library: Library
    let series: TrackedSeries

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SeriesRow(series: series)
            if let nextEpisode = series.nextEpisode {
                Button("Mark \(nextEpisode.shorthand) watched") {
                    library.markNextEpisodeWatched(series)
                }
                // Bordered, so the button is the tap target and not the whole row.
                .buttonStyle(.bordered)
            }
        }
        .swipeActions(edge: .trailing) {
            if series.position != nil {
                Button("Un-watch", systemImage: "arrow.uturn.backward") {
                    library.unwatchLastEpisode(series)
                }
            }
        }
    }
}

/// A series as the Watch App draws it, Watching or Waiting alike: Poster and title, where
/// the user got to and where they watch it, and the Next Episode Line.
private struct SeriesRow: View {
    let series: TrackedSeries

    @ScaledMetric(relativeTo: .headline) private var posterHeight = 45
    @ScaledMetric(relativeTo: .footnote) private var logoHeight = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                // Nothing for VoiceOver to say: the title is right beside it.
                WatchPoster(poster: series.poster, height: posterHeight)
                    .accessibilityHidden(true)
                Text(series.title)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            positionAndService
                .font(.footnote)
                .foregroundStyle(.secondary)
            NextEpisodeLineView(line: series.nextEpisodeLine)
        }
        .padding(.vertical, 2)
    }

    /// The Position, then the Streaming Service's Logo, or its name where it has none —
    /// one run of text in the name case, so it wraps at large text sizes.
    @ViewBuilder
    private var positionAndService: some View {
        let position = series.position?.shorthand ?? "Not started"
        if let service = series.streamingService,
           let logo = service.logo.flatMap(UIImage.init(data:)) {
            HStack(spacing: 4) {
                Text(verbatim: "\(position) ·")
                Image(uiImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(height: logoHeight)
                    .accessibilityLabel(service.name)
            }
        } else if let service = series.streamingService {
            Text(verbatim: "\(position) · \(service.name)")
        } else {
            Text(verbatim: position)
        }
    }
}

/// A Poster slot: the bytes where there are some, the `photo` symbol where there are none or
/// they won't decode — in TMDB's 2:3 frame either way, so rows line up.
private struct WatchPoster: View {
    let poster: Data?
    let height: CGFloat

    var body: some View {
        Group {
            if let image = poster.flatMap(UIImage.init(data:)) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: height / 3))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.fill.tertiary)
            }
        }
        .frame(width: height * 2 / 3, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

#Preview {
    WatchingListView(library: try! Library.inMemory())
}
