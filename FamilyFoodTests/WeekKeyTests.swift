import XCTest
@testable import FamilyFood

final class WeekKeyTests: XCTestCase {
    private func date(_ iso: String) -> Date {
        let fmt = ISO8601DateFormatter()
        return fmt.date(from: iso)!
    }

    // MARK: - Identity & navigation

    func test_startDate_is_a_monday_and_advanced_shifts_by_one_week() {
        let key = WeekKey(containing: date("2026-06-10T12:00:00+02:00"))   // a Wednesday
        let weekday = Calendar.mondayFirst.component(.weekday, from: key.startDate)
        XCTAssertEqual(weekday, 2)   // Monday
        XCTAssertEqual(key.advanced(by: 1).startDate,
                       key.startDate.addingTimeInterval(7 * 86400))
        XCTAssertEqual(key.advanced(by: 1).advanced(by: -1), key)
    }

    /// A wall-clock time in the app's calendar. Week boundaries are local, so a test about
    /// them must not bake in a UTC offset — it would only pass in that one timezone.
    private func local(_ year: Int, _ month: Int, _ day: Int, hour: Int) -> Date {
        Calendar.mondayFirst.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func test_all_days_of_one_week_share_the_same_key() {
        let monday = WeekKey(containing: local(2026, 6, 8, hour: 0))     // Monday, first minute
        let sunday = WeekKey(containing: local(2026, 6, 14, hour: 23))   // Sunday, late evening
        XCTAssertEqual(monday, sunday)
        XCTAssertLessThan(monday, monday.advanced(by: 1))
    }

    // MARK: - Day lookup

    func test_date_for_monday_equals_week_start() {
        let key = WeekKey(yearForWeekOfYear: 2026, weekOfYear: 20)   // Mon 11 – Sun 17 May 2026
        XCTAssertEqual(key.date(for: .monday), key.startDate)
    }

    func test_date_for_sunday_is_six_days_after_start() {
        let key = WeekKey(yearForWeekOfYear: 2026, weekOfYear: 20)
        let expected = Calendar.mondayFirst.date(byAdding: .day, value: 6, to: key.startDate)!
        XCTAssertEqual(key.date(for: .sunday), expected)
    }

    func test_isToday_is_true_only_for_the_weekday_matching_now() {
        let key = WeekKey(yearForWeekOfYear: 2026, weekOfYear: 20)
        let wednesdayMorning = key.date(for: .wednesday).addingTimeInterval(9 * 3600)
        XCTAssertTrue(key.isToday(.wednesday, now: wednesdayMorning))
        XCTAssertFalse(key.isToday(.tuesday, now: wednesdayMorning))
    }

    // MARK: - Codable

    func test_codable_round_trips_as_iso_week_string() throws {
        let key = WeekKey(containing: date("2026-06-10T12:00:00+02:00"))
        let data = try JSONEncoder().encode([key])
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("-W"), "expected compact week string, got \(json)")
        XCTAssertEqual(try JSONDecoder().decode([WeekKey].self, from: data), [key])
    }

    // MARK: - Legacy WeeklyPlan migration (weekStartDate → weekKey)

    func test_legacy_weeklyPlan_json_migrates_weekStartDate_to_weekKey() throws {
        // Legacy shape: absolute weekStartDate instant, no weekKey field.
        let mondayBerlin = date("2026-06-08T00:00:00+02:00")
        var legacy = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(WeeklyPlan(weekKey: .current))) as! [String: Any]
        legacy.removeValue(forKey: "weekKey")
        legacy["weekStartDate"] = mondayBerlin.timeIntervalSinceReferenceDate
        let data = try JSONSerialization.data(withJSONObject: legacy)

        let plan = try JSONDecoder().decode(WeeklyPlan.self, from: data)

        XCTAssertEqual(plan.weekKey, WeekKey(containing: date("2026-06-10T12:00:00+02:00")))
        XCTAssertEqual(plan.slots.count, 7)   // slots survive migration
    }

    /// A stored Monday-midnight instant must land in the same week no matter which
    /// timezone the device is in when it migrates (vacation scenario from the review).
    func test_legacy_migration_week_is_timezone_independent() {
        let mondayMidnightBerlin = date("2026-06-08T00:00:00+02:00")
        let shifted = mondayMidnightBerlin.addingTimeInterval(WeeklyPlan.legacyMidWeekShift)

        let keys = ["Europe/Berlin", "Pacific/Auckland", "Pacific/Honolulu"].map { zone -> WeekKey in
            var cal = Calendar(identifier: .gregorian)
            cal.firstWeekday = 2
            cal.minimumDaysInFirstWeek = 4
            cal.timeZone = TimeZone(identifier: zone)!
            return WeekKey(containing: shifted, calendar: cal)
        }

        XCTAssertEqual(Set(keys).count, 1, "expected one week, got \(keys)")
    }

    // MARK: - Duplicate weeks merge deterministically

    @MainActor
    func test_two_stored_plans_for_the_same_week_keep_the_later_record() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let store = PlanStore(directory: tmp)

        var older = WeeklyPlan(weekKey: .current)
        older.slots[0].meal = PlannedMeal(name: "Alt")
        var newer = WeeklyPlan(weekKey: .current)
        newer.slots[0].meal = PlannedMeal(name: "Neu")
        store.saveWeeklyPlans([older, newer])   // persist() always writes the active plan last

        let vm = MealPlanViewModel(store: store)
        XCTAssertEqual(vm.slot(for: .monday)?.meal?.name, "Neu")
    }
}
