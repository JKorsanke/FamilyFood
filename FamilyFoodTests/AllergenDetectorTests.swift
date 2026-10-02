import XCTest
@testable import FamilyFood

final class AllergenDetectorTests: XCTestCase {

    // MARK: "Ei" — word/suffix matching (the keyword is a substring of half the vocabulary)

    func test_ei_as_sole_ingredient_is_detected() {
        XCTAssertEqual(inferAllergenTags(from: ["Ei"]), ["Ei"])
    }

    func test_ei_as_final_ingredient_is_detected() {
        XCTAssertTrue(inferAllergenTags(from: ["Mehl", "Zucker", "Ei"]).contains("Ei"))
    }

    func test_ei_as_compound_suffix_is_detected() {
        XCTAssertEqual(inferAllergenTags(from: ["Spiegelei"]), ["Ei"])
    }

    func test_ei_inside_other_words_is_not_detected() {
        XCTAssertFalse(inferAllergenTags(from: ["Reis", "Eis", "Weintrauben"]).contains("Ei"))
    }

    func test_curry_yields_no_tags() {
        XCTAssertEqual(inferAllergenTags(from: ["Curry"]), [])
    }

    // MARK: German compounds must keep matching their root keyword (substring on purpose)

    func test_compound_ingredients_match_their_root_keyword() {
        XCTAssertEqual(inferAllergenTags(from: ["Vollkornmehl"]), ["Gluten"])
        XCTAssertEqual(inferAllergenTags(from: ["Sojaschnetzel"]), ["Soja"])
    }

    // MARK: General behavior

    func test_multiple_allergens_are_reported_in_check_order() {
        let tags = inferAllergenTags(from: ["Weizenmehl", "Milch", "Garnelen"])
        XCTAssertEqual(tags, ["Gluten", "Milch", "Schalentiere"])
    }

    func test_eigelb_and_mayonnaise_count_as_ei() {
        XCTAssertEqual(inferAllergenTags(from: ["Eigelb"]), ["Ei"])
        XCTAssertEqual(inferAllergenTags(from: ["Mayonnaise"]), ["Ei"])
    }

    func test_matching_is_case_insensitive() {
        XCTAssertEqual(inferAllergenTags(from: ["PARMESAN"]), ["Milch"])
    }

    func test_empty_input_yields_no_tags() {
        XCTAssertEqual(inferAllergenTags(from: []), [])
    }
}
