import Foundation

/// Timezone-stable identity of a calendar week (week-year + week number), e.g. `2026-W25`.
///
/// Plans used to be keyed by their Monday-midnight `Date` — an absolute instant derived in
/// whatever timezone the device was in at the time. After a timezone change every stored
/// key mismatched the freshly computed Monday, orphaning the user's plans. Week numbers
/// are what people mean by "this week"; they survive travel.
struct WeekKey: Hashable, Codable, Comparable, CustomStringConvertible {
    let yearForWeekOfYear: Int
    let weekOfYear: Int

    init(yearForWeekOfYear: Int, weekOfYear: Int) {
        self.yearForWeekOfYear = yearForWeekOfYear
        self.weekOfYear = weekOfYear
    }

    /// The week containing `date`, by the app's Monday-first calendar.
    init(containing date: Date, calendar: Calendar = .mondayFirst) {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        self.init(yearForWeekOfYear: comps.yearForWeekOfYear ?? 2000,
                  weekOfYear: comps.weekOfYear ?? 1)
    }

    static var current: WeekKey { WeekKey(containing: Date()) }

    /// Monday 00:00 of this week in the device's *current* timezone. Display and date
    /// math only — never use the result as identity.
    var startDate: Date {
        let comps = DateComponents(weekOfYear: weekOfYear, yearForWeekOfYear: yearForWeekOfYear)
        return Calendar.mondayFirst.date(from: comps) ?? Date()
    }

    func advanced(by weeks: Int) -> WeekKey {
        guard let shifted = Calendar.mondayFirst.date(byAdding: .weekOfYear, value: weeks, to: startDate)
        else { return self }
        return WeekKey(containing: shifted)
    }

    // MARK: - Day lookup

    /// The calendar date of `weekday` within this week, in the app's Monday-first calendar.
    /// Monday → `startDate`, Sunday → six days later. Display / today-detection only.
    func date(for weekday: Weekday) -> Date {
        Calendar.mondayFirst.date(byAdding: .day, value: weekday.rawValue - 1, to: startDate) ?? startDate
    }

    /// Whether `weekday` of this week falls on the same calendar day as `now`.
    func isToday(_ weekday: Weekday, now: Date = Date()) -> Bool {
        Calendar.mondayFirst.isDate(date(for: weekday), inSameDayAs: now)
    }

    static func < (lhs: WeekKey, rhs: WeekKey) -> Bool {
        (lhs.yearForWeekOfYear, lhs.weekOfYear) < (rhs.yearForWeekOfYear, rhs.weekOfYear)
    }

    var description: String { String(format: "%04d-W%02d", yearForWeekOfYear, weekOfYear) }

    // MARK: Codable — stored as the compact string so plan files stay human-readable.

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        let parts = raw.split(separator: "-W")
        guard parts.count == 2, let year = Int(parts[0]), let week = Int(parts[1]) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Not a week key: \(raw)"))
        }
        self.init(yearForWeekOfYear: year, weekOfYear: week)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
