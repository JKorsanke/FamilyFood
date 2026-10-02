import XCTest
@testable import FamilyFood

final class PlanStoreTests: XCTestCase {
    var tmp: URL!
    var store: PlanStore!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        store = PlanStore(directory: tmp)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    func test_weekly_plans_round_trip() {
        var plan = WeeklyPlan(weekKey: .current)
        plan.slots[0].meal = PlannedMeal(name: "Pasta")
        plan.slots[2].meal = PlannedMeal(name: "Abendbrot", kind: .abendbrot(auto: true))
        store.saveWeeklyPlans([plan])

        let loaded = store.loadWeeklyPlans()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.weekKey, .current)
        XCTAssertEqual(loaded.first?.slots[0].meal?.name, "Pasta")
        XCTAssertEqual(loaded.first?.slots[2].meal?.isAuto, true)   // isAuto survives
    }

    func test_kita_plans_round_trip() {
        let kita = KitaMealPlan.mock
        store.saveKitaPlans([kita])
        XCTAssertEqual(store.loadKitaPlans().first?.id, kita.id)
        XCTAssertEqual(store.loadKitaPlans().first?.monday.meal, kita.monday.meal)
    }

    func test_load_is_empty_when_no_file_exists() {
        XCTAssertTrue(store.loadWeeklyPlans().isEmpty)
        XCTAssertTrue(store.loadKitaPlans().isEmpty)
    }

    func test_weekly_and_kita_use_separate_files() {
        store.saveWeeklyPlans([WeeklyPlan(weekKey: .current)])
        XCTAssertEqual(store.loadWeeklyPlans().count, 1)
        XCTAssertTrue(store.loadKitaPlans().isEmpty)   // not clobbered
    }

    // MARK: - Corruption tolerance

    private var plansURL: URL { tmp.appendingPathComponent("weekly_plans.json") }
    private var backupURL: URL { tmp.appendingPathComponent("weekly_plans.backup.json") }

    /// Two valid plans with one malformed record between them.
    private func writePartiallyCorruptFile() throws -> Data {
        var plan1 = WeeklyPlan(weekKey: .current)
        plan1.slots[0].meal = PlannedMeal(name: "Pasta")
        let plan2 = WeeklyPlan(weekKey: WeekKey.current.advanced(by: 1))
        let enc = JSONEncoder()
        let good1 = String(data: try enc.encode(plan1), encoding: .utf8)!
        let good2 = String(data: try enc.encode(plan2), encoding: .utf8)!
        let json = Data("[\(good1), {\"id\": \"not-a-plan\"}, \(good2)]".utf8)
        try json.write(to: plansURL)
        return json
    }

    func test_one_malformed_record_keeps_the_valid_ones() throws {
        _ = try writePartiallyCorruptFile()
        let loaded = store.loadWeeklyPlans()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.first?.slots[0].meal?.name, "Pasta")
    }

    func test_partially_corrupt_file_is_backed_up_before_the_next_save() throws {
        let original = try writePartiallyCorruptFile()
        let loaded = store.loadWeeklyPlans()

        store.saveWeeklyPlans(loaded)   // overwrites weekly_plans.json

        XCTAssertEqual(try Data(contentsOf: backupURL), original)
        XCTAssertEqual(store.loadWeeklyPlans().count, 2)
    }

    func test_unreadable_file_is_backed_up_and_loads_empty() throws {
        let garbage = Data("not json at all".utf8)
        try garbage.write(to: plansURL)

        XCTAssertTrue(store.loadWeeklyPlans().isEmpty)
        store.saveWeeklyPlans([WeeklyPlan(weekKey: .current)])

        XCTAssertEqual(try Data(contentsOf: backupURL), garbage)
        XCTAssertEqual(store.loadWeeklyPlans().count, 1)   // store is usable again
    }
}
