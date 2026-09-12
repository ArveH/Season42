import SwiftUI

/// Draws a series' Next Episode Line — the Library's series row and all three of the
/// Watching tab's rows draw this one, so a Release Slot and a Next Episode Date read the
/// same way everywhere either is drawn.
///
/// Draws nothing at all, not an empty line, for a series with neither. Never judges what
/// it is handed: a date that has gone by is still what the row says, and a Slot says the
/// recurrence the user entered rather than an occurrence worked out from today, so the
/// line never changes on its own (ADR-0016).
struct NextEpisodeLineView: View {
    /// What the series says about its next episode, or nil where it says nothing.
    let line: NextEpisodeLine?

    var body: some View {
        if let text {
            text
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var text: Text? {
        switch line {
        case .releaseSlot(let slot):
            Text("\(slot.pluralWeekday) at \(slot.formattedTime)")
        case .nextEpisodeDate(let date):
            Text("Next episode \(date.formatted(date: .abbreviated, time: .omitted))")
        case nil:
            nil
        }
    }
}

#Preview {
    List {
        NextEpisodeLineView(line: .nextEpisodeDate(.now.addingTimeInterval(7 * 86_400)))
        NextEpisodeLineView(line: .nextEpisodeDate(.now.addingTimeInterval(-7 * 86_400)))
        NextEpisodeLineView(line: .releaseSlot(ReleaseSlot(weekday: 3, hour: 21, minute: 0)))
        NextEpisodeLineView(line: nil)
    }
}
