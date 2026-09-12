import Foundation

/// When a Tracked Series' episodes turn up week after week: a weekday and a time of day,
/// entered together and set or unset as one thing. A series with no Release Slot has no
/// weekly pattern recorded — there is no day without a time and no time without a day.
///
/// Wall-clock local and carrying no time zone (ADR-0016): a weekday and minutes past
/// midnight rather than a `Date`, because this is the user's own note about when to look
/// and it should read the same after they land somewhere else.
struct ReleaseSlot: Codable, Hashable, Comparable, Sendable {
    /// The weekday, in `Calendar`'s own numbering: 1 for Sunday through 7 for Saturday,
    /// so it can be compared against `Calendar.component(.weekday:from:)` unconverted.
    var weekday: Int
    /// The time of day, as minutes since local midnight.
    var minutesPastMidnight: Int

    /// - Parameter weekday: held to 1...7, so the seven weekday words below cover every
    ///   slot there is. Nothing in the app can ask for an eighth day; this is what makes
    ///   that true rather than assumed.
    init(weekday: Int, minutesPastMidnight: Int) {
        self.weekday = min(max(weekday, 1), 7)
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

    /// The weekday in the plural — "Tuesdays" — because a row teaches the pattern rather
    /// than naming one instance of it. Seven strings rather than a formatted weekday with
    /// an `s` on the end: the plural is a fact about English, not about dates (ADR-0016).
    static func pluralWeekday(_ weekday: Int) -> String {
        switch weekday {
        case 1: String(localized: "Sundays")
        case 2: String(localized: "Mondays")
        case 3: String(localized: "Tuesdays")
        case 4: String(localized: "Wednesdays")
        case 5: String(localized: "Thursdays")
        case 6: String(localized: "Fridays")
        // Saturday, and the fallback for a weekday off the end — which only a store
        // written by something other than this app could hold.
        default: String(localized: "Saturdays")
        }
    }

    var pluralWeekday: String { Self.pluralWeekday(weekday) }

    /// Earlier in the week first, and earlier in the day within a weekday. An ordering of
    /// the value itself, in the week's own terms — the Waiting listing does not use it:
    /// that ranks by `nextOccurrenceDay(onOrAfter:in:)`, which depends on what day it is.
    static func < (slot: ReleaseSlot, other: ReleaseSlot) -> Bool {
        (slot.weekday, slot.minutesPastMidnight) < (other.weekday, other.minutesPastMidnight)
    }

    /// The time of day as this device writes times, so a 12-hour device reads "9:00 PM"
    /// where a 24-hour one reads "21:00". Set on a day rather than counted in seconds from
    /// midnight: an hour is not always 3,600 seconds from the one before it, and the slot
    /// says a wall-clock time on every day of the year, the two the clocks change included.
    var formattedTime: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let time = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today)
        return (time ?? today).formatted(date: .omitted, time: .shortened)
    }
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
