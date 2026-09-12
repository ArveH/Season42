import SwiftUI

/// The one line every row that lists a Tracked Series says its schedule on — the Library's
/// series row and all three of the Watching tab's rows — so a Release Slot and a Next
/// Episode Date read the same way everywhere either is drawn.
///
/// Draws nothing at all, not an empty line, for a series with neither. Never judges what
/// it is handed: a date that has gone by is still what the row says, and a Slot says the
/// recurrence the user entered rather than an occurrence worked out from today, so the
/// line never changes on its own (ADR-0016).
struct NextEpisodeLine: View {
    /// What the series says about its next episode, or nil where it says nothing.
    let schedule: NextEpisodeSchedule?

    var body: some View {
        if let text {
            text
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var text: Text? {
        switch schedule {
        case .releaseSlot(let slot):
            Text("\(slot.pluralWeekday) at \(slot.formattedTime)")
        case .nextEpisodeDate(let date):
            Text("Next episode \(date.formatted(date: .abbreviated, time: .omitted))")
        case nil:
            nil
        }
    }
}

extension ReleaseSlot {
    /// The weekday in the plural — "Tuesdays" — because the row teaches the pattern rather
    /// than naming one instance of it. Seven strings rather than a formatted weekday with
    /// an `s` on the end: the plural is a fact about English, not about dates (ADR-0016).
    var pluralWeekday: String {
        switch weekday {
        case 1: String(localized: "Sundays")
        case 2: String(localized: "Mondays")
        case 3: String(localized: "Tuesdays")
        case 4: String(localized: "Wednesdays")
        case 5: String(localized: "Thursdays")
        case 6: String(localized: "Fridays")
        default: String(localized: "Saturdays")
        }
    }

    /// The time of day as this device writes times, so a 12-hour device reads "9:00 PM"
    /// where a 24-hour one reads "21:00".
    var formattedTime: String {
        Date.now.startOfDayInCurrentCalendar
            .addingTimeInterval(TimeInterval(minutesPastMidnight) * 60)
            .formatted(date: .omitted, time: .shortened)
    }
}

private extension Date {
    var startOfDayInCurrentCalendar: Date { Calendar.current.startOfDay(for: self) }
}

#Preview {
    List {
        NextEpisodeLine(schedule: .nextEpisodeDate(.now.addingTimeInterval(7 * 86_400)))
        NextEpisodeLine(schedule: .nextEpisodeDate(.now.addingTimeInterval(-7 * 86_400)))
        NextEpisodeLine(schedule: .releaseSlot(ReleaseSlot(weekday: 3, hour: 21, minute: 0)))
        NextEpisodeLine(schedule: nil)
    }
}
