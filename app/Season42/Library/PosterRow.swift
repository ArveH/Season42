import SwiftUI

/// A row that leads with a Library Entry's Poster and stacks its text to the right. Every
/// row that lists an entry draws through this — both Library rows, and the Watching tab's
/// Watching and Waiting rows — so a column of them lines up and the user finds things by
/// looking rather than by reading.
///
/// The slot is drawn whether or not there is a Poster: `Poster` stands in for one that
/// isn't there with the `photo` symbol, distinct from the `tv` that stands in for a
/// missing Logo further down the same row, and in the same frame — so the rows either side
/// of an entry with no picture line up with it. The bytes are the entry's own, so a row
/// draws with the BFF stopped, unreachable or never deployed (ADR-0013).
///
/// What goes to the right is the caller's, stack and spacing and all: the rows differ in
/// what they say and in whether anything under the text can be tapped.
struct PosterRow<Content: View>: View {
    /// The entry's adopted Poster, or nil where it has none.
    let poster: Data?

    @ViewBuilder let content: Content

    @ScaledMetric(relativeTo: .headline) private var posterHeight = 66

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Nothing for VoiceOver to say: the title it would be labelled with is the
            // text right beside it, and a row that says the title twice is worse than one
            // that says it once.
            Poster(poster: poster, height: posterHeight)
                .accessibilityHidden(true)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    List {
        PosterRow(poster: PreviewPoster.bytes(.systemIndigo)) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Severance").font(.headline)
                Text("Watching · S2E4").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        PosterRow(poster: nil) {
            VStack(alignment: .leading, spacing: 4) {
                Text("The Bear").font(.headline)
                Text("Planned · Not started").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
