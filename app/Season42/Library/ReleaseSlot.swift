import Foundation

/// When a Tracked Series' episodes turn up week after week: a weekday and a time of day,
/// entered together and set or unset as one thing. A series with no Release Slot has no
/// weekly pattern recorded — there is no day without a time and no time without a day.
///
/// Wall-clock local and carrying no time zone (ADR-0016): a weekday and minutes past
/// midnight rather than a `Date`, because this is the user's own note about when to look
/// and it should read the same after they land somewhere else.
struct ReleaseSlot: Codable, Hashable, Sendable {
    /// The weekday, in `Calendar`'s own numbering: 1 for Sunday through 7 for Saturday,
    /// so it can be compared against `Calendar.component(.weekday:from:)` unconverted.
    var weekday: Int
    /// The time of day, as minutes since local midnight.
    var minutesPastMidnight: Int

    init(weekday: Int, minutesPastMidnight: Int) {
        self.weekday = weekday
        self.minutesPastMidnight = minutesPastMidnight
    }

    /// The same slot said the way a form gathers it — an hour and a minute of the day.
    init(weekday: Int, hour: Int, minute: Int) {
        self.init(weekday: weekday, minutesPastMidnight: hour * 60 + minute)
    }

    /// Every weekday there is, in `Calendar`'s numbering — what a picker walks.
    static let weekdays = Array(1...7)

    var hour: Int { minutesPastMidnight / 60 }
    var minute: Int { minutesPastMidnight % 60 }
}

extension ReleaseSlot {
    /// The day this slot next lands on, as the start of that day, rolling over at local
    /// midnight rather than at the slot's own time: a slot falling today is today's for
    /// the whole of today, even once the hour has gone by (ADR-0016).
    ///
    /// Only ever a rank — the Waiting listing orders by it and no screen ever draws it.
    func nextOccurrenceDay(onOrAfter now: Date, in calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        let daysAway = (weekday - calendar.component(.weekday, from: today) + 7) % 7
        return calendar.date(byAdding: .day, value: daysAway, to: today) ?? today
    }
}
