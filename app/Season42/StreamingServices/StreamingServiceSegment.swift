import SwiftUI

/// The one place a row draws where its Library Entry is watched. The Watching tab's
/// series row and both Library rows use it, so where the Streaming Service reads one way
/// it reads that way everywhere.
///
/// A service the user has adopted a Logo onto draws as that Logo; one with none draws as
/// its name. The segment owns the `·` that precedes either, because an entry naming no
/// service must leave no separator behind — and it owns the rest of the subtitle too, so
/// that the name case stays a single run of text and wraps and truncates as it always has.
struct StreamingServiceSegment: View {
    /// The rest of the subtitle, which this segment follows.
    let subtitle: String

    /// Where the entry is watched, or nil when the user has named nowhere.
    let service: StreamingService?

    /// Tall enough to make out at a glance and still one line of the subtitle; raised here
    /// and nowhere else, so Library rows and Watching rows can't come to disagree.
    @ScaledMetric(relativeTo: .subheadline) private var logoHeight = 24

    var body: some View {
        // Drawn through the Logo slot rather than by hand, so the one Logo in the app that
        // is drawn beside a name and the one drawn instead of it are the same drawing. The
        // slot's `tv` stand-in is unreachable here: the branch is only taken by a service
        // that has a Logo, because a service without one draws as its name.
        if let service, service.logoToDraw != nil {
            HStack(spacing: 4) {
                Text(verbatim: "\(subtitle) ·")
                StreamingServiceLogo(service: service, height: logoHeight)
                    .accessibilityLabel(service.name)
            }
        } else {
            text
        }
    }

    /// The whole subtitle as one `Text`, for the entries whose service has no Logo to
    /// draw — and for those naming no service at all.
    private var text: Text {
        guard let service else { return Text(verbatim: subtitle) }
        return Text(verbatim: "\(subtitle) · \(service.name)")
    }
}

/// A Logo-sized slot: the Logo bytes handed to it, or the `tv` symbol in secondary grey
/// standing in where there are none — or where they won't decode, which draws as no Logo
/// rather than as a failure.
///
/// Every Logo the app draws is drawn here, a Logo a service already carries and one a
/// search is offering alike, so the picture on a result row is the picture the user gets.
struct StreamingServiceLogo: View {
    /// The image bytes, or nil for the stand-in.
    let logo: Data?

    /// How tall the slot is, so that a column of them lines up whichever of the two it
    /// happens to be drawing. Every caller asks for a different height, and all of them
    /// scale theirs with the text beside it.
    let height: CGFloat

    /// The Logo a Streaming Service carries, which is what everywhere but the search
    /// results is drawing.
    init(service: StreamingService, height: CGFloat) {
        self.init(logo: service.logo, height: height)
    }

    init(logo: Data?, height: CGFloat) {
        self.logo = logo
        self.height = height
    }

    var body: some View {
        if let image = logo.flatMap(UIImage.init(data:)) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(height: height)
        } else {
            Image(systemName: "tv")
                .foregroundStyle(.secondary)
                .frame(height: height)
        }
    }
}

private extension StreamingService {
    /// The adopted Logo ready to be drawn, or nil where there is none — or where the bytes
    /// won't decode, which draws as no Logo rather than as a failure: the name and the `tv`
    /// stand-in are already what a service without one shows.
    var logoToDraw: Image? {
        guard let logo, let image = UIImage(data: logo) else { return nil }
        return Image(uiImage: image)
    }
}

/// Stand-in Logos for the previews in this folder. A real one is adopted from the BFF,
/// which a preview has no business starting, so this is how a Logo is seen in one.
///
/// A namespace of its own rather than an extension on `Data`, and not behind `#if DEBUG`:
/// a `#Preview` is compiled in every configuration, so what it calls has to be too, and
/// this way what ships is one obviously preview-shaped type rather than a wider `Data`.
enum PreviewLogo {
    static func bytes(_ color: UIColor) -> Data {
        let size = CGSize(width: 154, height: 90)
        return UIGraphicsImageRenderer(size: size).pngData { _ in
            color.setFill()
            UIBezierPath(
                roundedRect: CGRect(origin: .zero, size: size),
                cornerRadius: 16
            ).fill()
        }
    }
}

#Preview {
    let withLogo = StreamingService(name: "Netflix", logo: PreviewLogo.bytes(.systemRed))
    let withoutLogo = StreamingService(name: "NRK TV")

    List {
        StreamingServiceSegment(subtitle: "Watching · S2E4", service: withLogo)
        StreamingServiceSegment(subtitle: "Watching · S2E4", service: withoutLogo)
        StreamingServiceSegment(subtitle: "Watching · S2E4", service: nil)
    }
    .font(.subheadline)
    .foregroundStyle(.secondary)
}
