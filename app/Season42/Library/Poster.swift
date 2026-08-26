import SwiftUI

/// A Poster slot, drawing the bytes where there are some and a stand-in where there are not.
/// One view for both, so the two are the same size and a screen that shows a Poster and one
/// that shows there is none line up.
///
/// The frame is TMDB's poster shape, 2:3, and the height is the caller's: every caller sizes
/// its slot against the text beside it. Bytes that won't decode draw as no Poster rather than
/// as a failure — a picture that isn't there is what the stand-in already says.
struct Poster: View {
    /// The image bytes, or nil for the stand-in.
    let poster: Data?

    /// How tall the slot is. The width follows from it, so a column of them lines up whichever
    /// of the two it happens to be drawing.
    let height: CGFloat

    var body: some View {
        Group {
            if let image = poster.flatMap(UIImage.init(data:)) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                // Not the `tv` the missing Logo stands in for: inside one row the two must not
                // look alike, because "no poster" and "no logo" are different things missing.
                Image(systemName: "photo")
                    .font(.system(size: height / 3))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.fill.tertiary)
            }
        }
        .frame(width: height * 2 / 3, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview("A poster and none") {
    HStack(spacing: 16) {
        Poster(poster: PreviewPoster.bytes(.systemIndigo), height: 120)
        Poster(poster: nil, height: 120)
    }
}

/// A stand-in Poster for the previews around it. A real one is copied off the BFF, which a
/// preview has no business starting, so this is how a Poster is seen in one.
///
/// A namespace of its own rather than an extension on `Data`, and not behind `#if DEBUG`: a
/// `#Preview` is compiled in every configuration, so what it calls has to be too.
enum PreviewPoster {
    static func bytes(_ color: UIColor) -> Data {
        let size = CGSize(width: 342, height: 513)
        return UIGraphicsImageRenderer(size: size).pngData { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
