import SwiftUI

/// The one line every row that lists a Tracked Series says its Next Episode Date on —
/// both Library rows' series row and both of the Watching tab's — so the date reads the
/// same way everywhere it is drawn.
///
/// Draws nothing at all, not an empty line, for a series with no date. Never judges the
/// date: one that has gone by is still what the row says, because the row saying the
/// episode aired on Tuesday is information, not an error to hide.
struct NextEpisodeDateLine: View {
    /// The Next Episode Date, or nil where the user has recorded none.
    let date: Date?

    var body: some View {
        if let date {
            Text("Next episode \(date.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    List {
        NextEpisodeDateLine(date: .now.addingTimeInterval(7 * 86_400))
        NextEpisodeDateLine(date: .now.addingTimeInterval(-7 * 86_400))
        NextEpisodeDateLine(date: nil)
    }
}
