import XCTest
@testable import FamilyFood

@MainActor
final class AppStoreTests: XCTestCase {

    func test_kita_plans_persist_across_instances() {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = PlanStore(directory: tmp)

        let a1 = AppStore(store: store)
        a1.kitaPlans.append(.mock)

        let a2 = AppStore(store: store)
        XCTAssertEqual(a2.kitaPlans.count, 1)
        XCTAssertEqual(a2.kitaPlans.first?.id, KitaMealPlan.mock.id)
    }

    func test_removing_a_kita_plan_persists() {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = PlanStore(directory: tmp)

        let a1 = AppStore(store: store)
        a1.kitaPlans.append(.mock)
        a1.kitaPlans.removeAll { $0.id == KitaMealPlan.mock.id }

        let a2 = AppStore(store: store)
        XCTAssertTrue(a2.kitaPlans.isEmpty)
    }
}
