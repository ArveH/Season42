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

    @ScaledMetric(relativeTo: .subheadline) private var logoHeight = 16

    var body: some View {
        if let service, let logo = service.logoImage {
            HStack(spacing: 4) {
                Text(verbatim: "\(subtitle) ·")
                logo
                    .resizable()
                    .scaledToFit()
                    .frame(height: logoHeight)
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

/// A Logo-sized slot: the Logo a Streaming Service carries, or the `tv` symbol in
/// secondary grey standing in where it carries none.
struct StreamingServiceLogo: View {
    let service: StreamingService?

    /// How tall the slot is, so that a column of them lines up whichever of the two it
    /// happens to be drawing.
    let height: CGFloat

    var body: some View {
        if let logo = service?.logoImage {
            logo
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

extension StreamingService {
    /// The adopted Logo as something to draw, or nil where there is none — or where the
    /// bytes are not an image, which is drawn as no Logo rather than as a failure: the
    /// name and the `tv` stand-in are already what a service without one shows.
    var logoImage: Image? {
        guard let logo, let image = UIImage(data: logo) else { return nil }
        return Image(uiImage: image)
    }
}

extension Data {
    /// A stand-in Logo for previews. Nothing in the app can adopt a real one yet (#29),
    /// so this is how a Logo is seen at all before that lands. Not behind `#if DEBUG`:
    /// a `#Preview` is compiled in every configuration, so what it calls must be too.
    static func previewLogo(_ color: UIColor) -> Data {
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
    let withLogo = StreamingService(name: "Netflix", logo: .previewLogo(.systemRed))
    let withoutLogo = StreamingService(name: "NRK TV")

    List {
        StreamingServiceSegment(subtitle: "Watching · S2E4", service: withLogo)
        StreamingServiceSegment(subtitle: "Watching · S2E4", service: withoutLogo)
        StreamingServiceSegment(subtitle: "Watching · S2E4", service: nil)
    }
    .font(.subheadline)
    .foregroundStyle(.secondary)
}
