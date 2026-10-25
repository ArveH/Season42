import SwiftUI

/// The Watch App's one screen: the Watching listing in the Watching Order the user picked on
/// the phone, and the Waiting listing below it. Every rule about the order lives in
/// `WatchingListing`, as on the phone; this view names things and draws them.
///
/// Read-only for now: nothing on a row can be tapped, so nothing on the Watch App lapses a
/// row either. A series whose Status was changed on the phone is held where it is, drawn
/// as it was, until the next re-take sweeps it — never as a Lapsed Row (see Watch App in
/// GLOSSARY.md).
struct WatchingListView: View {
    @State private var listing: WatchingListing
    @State private var iCloud = ICloudAccount()
    @Environment(\.scenePhase) private var scenePhase

    init(library: Library) {
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
                        ForEach(listing.series) { SeriesRow(series: $0) }
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
