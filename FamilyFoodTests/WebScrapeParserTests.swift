import XCTest
@testable import FamilyFood

final class WebScrapeParserTests: XCTestCase {
    private let parser = WebScrapeParser(anthropicService: MockAnthropicParser())

    private func html(embedding jsonLD: String...) -> String {
        let scripts = jsonLD
            .map { #"<script type="application/ld+json">\#($0)</script>"# }
            .joined(separator: "\n")
        return "<html><head>\(scripts)</head><body><h1>Rezept</h1></body></html>"
    }

    // MARK: — JSON-LD shapes

    /// Yoast style (common on WordPress recipe blogs): everything wrapped in an @graph array.
    func test_graph_wrapped_recipe_is_found_and_mapped() throws {
        let json = """
        {"@context":"https://schema.org","@graph":[
          {"@type":"Article","name":"Blogpost"},
          {"@type":"Recipe","name":"Veganes Linsencurry",
           "description":"Cremig und schnell.",
           "image":["https://example.org/curry.jpg"],
           "recipeIngredient":["200 g rote Linsen","1 Dose Kokosmilch"],
           "prepTime":"PT10M","cookTime":"PT20M","totalTime":"PT30M",
           "recipeYield":"4 Portionen",
           "suitableForDiet":"https://schema.org/VeganDiet"}
        ]}
        """
        let draft = try XCTUnwrap(parser.parseJSONLD(from: html(embedding: json),
                                                     sourceURL: "https://example.org/r"))
        XCTAssertEqual(draft.title, "Veganes Linsencurry")
        XCTAssertEqual(draft.summary, "Cremig und schnell.")
        XCTAssertEqual(draft.imageURL, "https://example.org/curry.jpg")
        XCTAssertEqual(draft.prepTime, 10)
        XCTAssertEqual(draft.cookTime, 20)
        XCTAssertEqual(draft.totalTime, 30)
        XCTAssertEqual(draft.servings, "4")
        XCTAssertEqual(draft.servingsUnit, "Portionen")
        XCTAssertEqual(draft.dietStyle, .vegan)
        XCTAssertEqual(draft.sourceURL, "https://example.org/r")
        XCTAssertEqual(draft.ingredientGroups.count, 1)
        XCTAssertEqual(draft.ingredientGroups[0].ingredients.map(\.name),
                       ["200 g rote Linsen", "1 Dose Kokosmilch"])
    }

    /// Chefkoch style: single root object, image as an ImageObject.
    func test_single_object_with_image_object_is_mapped() throws {
        let json = """
        {"@context":"https://schema.org","@type":"Recipe","name":"Kartoffelgratin",
         "image":{"@type":"ImageObject","url":"https://example.org/gratin.jpg"},
         "recipeYield":"6","recipeIngredient":["1 kg Kartoffeln"]}
        """
        let draft = try XCTUnwrap(parser.parseJSONLD(from: html(embedding: json),
                                                     sourceURL: "https://example.org/g"))
        XCTAssertEqual(draft.title, "Kartoffelgratin")
        XCTAssertEqual(draft.imageURL, "https://example.org/gratin.jpg")
        XCTAssertEqual(draft.servings, "6")
        XCTAssertNil(draft.servingsUnit)
    }

    /// Array-of-objects root, @type itself an array, vegetarian diet.
    func test_array_root_and_array_type_are_handled() throws {
        let json = """
        [{"@type":"WebSite","name":"Foodblog"},
         {"@type":["Recipe","Thing"],"name":"Käsespätzle",
          "image":"https://example.org/spaetzle.jpg",
          "suitableForDiet":["https://schema.org/VegetarianDiet"]}]
        """
        let draft = try XCTUnwrap(parser.parseJSONLD(from: html(embedding: json),
                                                     sourceURL: "https://example.org/s"))
        XCTAssertEqual(draft.title, "Käsespätzle")
        XCTAssertEqual(draft.imageURL, "https://example.org/spaetzle.jpg")
        XCTAssertEqual(draft.dietStyle, .vegetarian)
    }

    /// A malformed first script block must not stop the scan of later blocks.
    func test_malformed_block_is_skipped_in_favour_of_a_later_recipe() throws {
        let broken = #"{"@type":"Recipe","name":"kaputt""#   // unterminated JSON
        let valid = #"{"@type":"Recipe","name":"Pfannkuchen"}"#
        let draft = try XCTUnwrap(parser.parseJSONLD(from: html(embedding: broken, valid),
                                                     sourceURL: "https://example.org/p"))
        XCTAssertEqual(draft.title, "Pfannkuchen")
    }

    /// JSON-LD values carry raw HTML (entities, <p> wrappers) on real
    /// sites — the mapped draft must already be display-clean.
    func test_jsonld_recipe_text_is_cleaned() throws {
        let json = """
        {"@type":"Recipe","name":"Mac &amp; Cheese",
         "description":"<p>Cremig &amp; schnell.</p><p>Mit Kartoffeln &#8211; vegan.</p>",
         "recipeIngredient":["200&nbsp;g Cashewkerne"]}
        """
        let draft = try XCTUnwrap(parser.parseJSONLD(from: html(embedding: json),
                                                     sourceURL: "https://example.org/m"))
        XCTAssertEqual(draft.title, "Mac & Cheese")
        XCTAssertEqual(draft.summary, "Cremig & schnell.\n\nMit Kartoffeln – vegan.")
        XCTAssertEqual(draft.ingredientGroups[0].ingredients[0].name, "200 g Cashewkerne")
    }

    func test_page_without_recipe_returns_nil() {
        let json = #"{"@type":"Article","name":"Nur ein Blogpost"}"#
        XCTAssertNil(parser.parseJSONLD(from: html(embedding: json), sourceURL: "https://example.org"))
    }

    func test_recipe_without_name_returns_nil() {
        let json = #"{"@type":"Recipe","recipeIngredient":["Mehl"]}"#
        XCTAssertNil(parser.parseJSONLD(from: html(embedding: json), sourceURL: "https://example.org"))
    }

    // MARK: — parseDuration (ISO-8601)

    func test_parseDuration_minutes_only() {
        XCTAssertEqual(parseDuration("PT30M"), 30)
    }

    func test_parseDuration_hours_and_minutes() {
        XCTAssertEqual(parseDuration("PT1H30M"), 90)
    }

    func test_parseDuration_hours_only() {
        XCTAssertEqual(parseDuration("PT1H"), 60)
    }

    /// Days are not parsed — documented limitation, the date part before "T" is skipped.
    func test_parseDuration_ignores_a_day_component() {
        XCTAssertEqual(parseDuration("P1DT2H"), 120)
    }

    func test_parseDuration_zero_and_garbage_return_nil() {
        XCTAssertNil(parseDuration("PT0M"))
        XCTAssertNil(parseDuration("30 Minuten"))
        XCTAssertNil(parseDuration(""))
        XCTAssertNil(parseDuration(nil))
    }
}
