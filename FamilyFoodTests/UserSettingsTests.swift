import XCTest
@testable import FamilyFood

final class UserSettingsTests: XCTestCase {

    func test_child_roundtrips_through_rawValue() {
        var settings = UserSettings()
        let child = Child(id: UUID(), name: "Lena")
        settings.children = [child]

        guard let restored = UserSettings(rawValue: settings.rawValue) else {
            XCTFail("UserSettings failed to decode from rawValue")
            return
        }

        XCTAssertEqual(restored.children.count, 1)
        XCTAssertEqual(restored.children[0].id, child.id)
        XCTAssertEqual(restored.children[0].name, "Lena")
    }

    func test_existing_settings_without_children_decode_to_empty_array() {
        let oldJson = """
        {"dietStyle":"omnivore","allergens":[],"warmMealDays":[1,2,3,4,5]}
        """
        guard let settings = UserSettings(rawValue: oldJson) else {
            XCTFail("Old UserSettings JSON failed to decode")
            return
        }
        XCTAssertEqual(settings.children, [])
    }

    func test_default_adults_is_one() {
        XCTAssertEqual(UserSettings().adults, 1)
    }

    func test_default_dietStyle_is_vegetarian() {
        XCTAssertEqual(UserSettings().dietStyle, .vegetarian)
    }

    func test_default_warmMealDays_is_monday_only() {
        XCTAssertEqual(UserSettings().warmMealDays, [.monday])
    }

    func test_default_maxCookTimeMinutes_is_30() {
        XCTAssertEqual(UserSettings().maxCookTimeMinutes, 30)
    }

    // MARK: - renameChild

    func test_renameChild_updates_name() {
        var settings = UserSettings()
        let child = Child(name: "Lena")
        settings.children = [child]

        settings.renameChild(id: child.id, to: "Mia")

        XCTAssertEqual(settings.children.map(\.name), ["Mia"])
        XCTAssertEqual(settings.children.first?.id, child.id)   // identity preserved
    }

    func test_renameChild_trims_whitespace() {
        var settings = UserSettings()
        let child = Child(name: "Lena")
        settings.children = [child]

        settings.renameChild(id: child.id, to: "  Mia  ")

        XCTAssertEqual(settings.children.first?.name, "Mia")
    }

    func test_renameChild_with_empty_name_removes_child() {
        var settings = UserSettings()
        let lena = Child(name: "Lena")
        let max = Child(name: "Max")
        settings.children = [lena, max]

        settings.renameChild(id: lena.id, to: "")

        XCTAssertEqual(settings.children.map(\.name), ["Max"])
    }

    func test_renameChild_with_whitespace_only_name_removes_child() {
        var settings = UserSettings()
        let child = Child(name: "Lena")
        settings.children = [child]

        settings.renameChild(id: child.id, to: "   ")

        XCTAssertTrue(settings.children.isEmpty)
    }

    func test_renameChild_unknown_id_is_noop() {
        var settings = UserSettings()
        let child = Child(name: "Lena")
        settings.children = [child]

        settings.renameChild(id: UUID(), to: "Mia")

        XCTAssertEqual(settings.children.map(\.name), ["Lena"])
    }

    func test_adults_roundtrips_through_rawValue() {
        var settings = UserSettings()
        settings.adults = 3

        guard let restored = UserSettings(rawValue: settings.rawValue) else {
            XCTFail("UserSettings failed to decode from rawValue")
            return
        }

        XCTAssertEqual(restored.adults, 3)
    }

    func test_existing_settings_without_adults_decode_to_default() {
        let oldJson = """
        {"dietStyle":"omnivore","allergens":[],"warmMealDays":[1,2,3,4,5]}
        """
        guard let settings = UserSettings(rawValue: oldJson) else {
            XCTFail("Old UserSettings JSON failed to decode")
            return
        }
        XCTAssertEqual(settings.adults, 1)
    }

    func test_existing_settings_without_maxCookTime_decode_to_nil() {
        // An absent key / saved "Zeit egal" must stay nil — NOT remapped to the new 30 default.
        // nil is a meaningful value (no limit), distinct from "unset".
        let oldJson = """
        {"dietStyle":"vegetarian","allergens":[],"warmMealDays":[1]}
        """
        guard let settings = UserSettings(rawValue: oldJson) else {
            XCTFail("Old UserSettings JSON failed to decode")
            return
        }
        XCTAssertNil(settings.maxCookTimeMinutes)
    }
}
