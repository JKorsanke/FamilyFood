import Foundation

extension Calendar {
    /// The app's single Monday-first Gregorian calendar. All week math (week starts,
    /// week-of-year comparisons, pager navigation) must go through this instance so
    /// week identity is computed the same way everywhere.
    ///
    /// `minimumDaysInFirstWeek = 4` makes week numbering true ISO-8601 — persisted
    /// `WeekKey`s depend on this rule staying fixed.
    static let mondayFirst: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        return cal
    }()
}

/// Decides whether an imported Kita plan belongs to a given plan week.
///
/// Kita plans carry their week only as loosely formatted strings (`weekOf`, or the
/// Monday's `date`), so matching is a fallback chain:
/// 1. `weekOf` resolved to a `WeekKey`
/// 2. `monday.date` resolved the same way
/// 3. nothing parseable → assume the plan is for the current week
///
/// Comparison is by `WeekKey` identity, not bare week-of-year number. The parser emits
/// dates as `dd.MM.` with no year (`AnthropicService`), so a year-less date is resolved
/// to the year that places it nearest `now` — comparing bare numbers instead would pit a
/// week number computed in the formatter's default year 2000 against one in the real
/// year, and the two only coincide by luck. In 2026 they were off by one, landing every
/// plan on the previous week.
enum KitaWeekMatcher {
    static func matches(_ kita: KitaMealPlan, weekStart: Date, now: Date = Date()) -> Bool {
        let target = WeekKey(containing: weekStart)

        if let key = weekKey(of: kita.weekOf, now: now)      { return key == target }
        if let key = weekKey(of: kita.monday.date, now: now) { return key == target }
        return WeekKey(containing: now) == target
    }

    /// Resolves a Kita date string to the calendar week it denotes, or nil if unparseable.
    /// `dd.MM.yyyy` honors its explicit year; `dd.MM.` (no year) is resolved to the year
    /// that places the date nearest `now`, so e.g. a late-December plan imported in early
    /// January still lands in the correct year.
    private static func weekKey(of dateString: String?, now: Date) -> WeekKey? {
        guard let str = dateString else { return nil }
        let cal = Calendar.mondayFirst
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")

        fmt.dateFormat = "dd.MM.yyyy"
        if let date = fmt.date(from: str) { return WeekKey(containing: date) }

        fmt.dateFormat = "dd.MM."
        if let bare = fmt.date(from: str) {
            let comps = cal.dateComponents([.day, .month], from: bare)
            guard let day = comps.day, let month = comps.month else { return nil }
            let nowYear = cal.component(.year, from: now)
            let resolved = [nowYear - 1, nowYear, nowYear + 1]
                .compactMap { cal.date(from: DateComponents(year: $0, month: month, day: day)) }
                .min { abs($0.timeIntervalSince(now)) < abs($1.timeIntervalSince(now)) }
            return resolved.map { WeekKey(containing: $0) }
        }
        return nil
    }
}
