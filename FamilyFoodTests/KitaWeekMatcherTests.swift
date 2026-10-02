import XCTest
@testable import FamilyFood

final class KitaWeekMatcherTests: XCTestCase {
    private let fmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd.MM.yyyy"
        return f
    }()

    /// Monday-first week start of the week containing the given dd.MM.yyyy date.
    private func weekStart(of dateString: String) -> Date {
        let date = fmt.date(from: dateString)!
        return Calendar.mondayFirst.dateInterval(of: .weekOfYear, for: date)!.start
    }

    private func kita(weekOf: String? = nil, mondayDate: String? = nil) -> KitaMealPlan {
        KitaMealPlan(weekOf: weekOf,
                     monday: KitaMealPlan.Day(date: mondayDate, meal: "Nudeln"))
    }

    // MARK: weekOf

    func test_weekOf_full_date_in_same_week_matches() {
        let kita = kita(weekOf: "08.06.2026")
        XCTAssertTrue(KitaWeekMatcher.matches(kita, weekStart: weekStart(of: "10.06.2026")))
    }

    func test_weekOf_full_date_in_other_week_does_not_match() {
        let kita = kita(weekOf: "15.06.2026")
        XCTAssertFalse(KitaWeekMatcher.matches(kita, weekStart: weekStart(of: "10.06.2026")))
    }

    // MARK: monday.date fallback

    func test_unparseable_weekOf_falls_back_to_monday_date() {
        let kita = kita(weekOf: "Sommerwoche", mondayDate: "08.06.2026")
        XCTAssertTrue(KitaWeekMatcher.matches(kita, weekStart: weekStart(of: "10.06.2026")))
    }

    func test_missing_weekOf_falls_back_to_monday_date() {
        let kita = kita(mondayDate: "08.06.2026")
        XCTAssertTrue(KitaWeekMatcher.matches(kita, weekStart: weekStart(of: "10.06.2026")))
    }

    /// "dd.MM." (no year — the only format the parser emits) resolves against `now`,
    /// so it matches the week of that day/month *in the current year*.
    func test_monday_date_without_year_resolves_against_now() {
        let kita = kita(mondayDate: "08.06.")
        let now = fmt.date(from: "10.06.2026")!
        XCTAssertTrue(KitaWeekMatcher.matches(kita, weekStart: weekStart(of: "08.06.2026"), now: now))
        XCTAssertFalse(KitaWeekMatcher.matches(kita, weekStart: weekStart(of: "15.06.2026"), now: now))
    }

    /// Regression: a year-less `dd.MM.` date must map to the *current-year* week,
    /// not whichever week that day fell in back in the formatter's default year 2000.
    /// Before the fix the plan landed one week early (current week → previous week).
    func test_yearless_date_maps_to_current_year_week_not_year_2000() {
        let now = fmt.date(from: "25.06.2026")!         // KW 26
        let kita = kita(mondayDate: "22.06.")           // Monday of KW 26, 2026
        // Maps to the real current week...
        XCTAssertTrue(KitaWeekMatcher.matches(kita, weekStart: weekStart(of: "22.06.2026"), now: now))
        // ...and NOT the previous week (the buggy target).
        XCTAssertFalse(KitaWeekMatcher.matches(kita, weekStart: weekStart(of: "15.06.2026"), now: now))
    }

    /// A year-less December date imported in early January resolves to the *previous*
    /// year, not the upcoming one (nearest-year-to-now wins).
    func test_yearless_december_date_imported_in_january_resolves_to_previous_year() {
        let now = fmt.date(from: "05.01.2027")!
        let kita = kita(mondayDate: "28.12.")           // Mon 28.12.2026, KW 53
        XCTAssertTrue(KitaWeekMatcher.matches(kita, weekStart: weekStart(of: "28.12.2026"), now: now))
        XCTAssertFalse(KitaWeekMatcher.matches(kita, weekStart: weekStart(of: "04.01.2027"), now: now))
    }

    // MARK: no parseable date → assume the plan is for the current week

    func test_no_parseable_date_matches_only_the_current_week() {
        let kita = kita(weekOf: "diese Woche", mondayDate: "Montag")
        let now = fmt.date(from: "10.06.2026")!
        let thisWeek = weekStart(of: "10.06.2026")
        let nextWeek = weekStart(of: "17.06.2026")
        XCTAssertTrue(KitaWeekMatcher.matches(kita, weekStart: thisWeek, now: now))
        XCTAssertFalse(KitaWeekMatcher.matches(kita, weekStart: nextWeek, now: now))
    }
}
