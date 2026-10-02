import XCTest
@testable import FamilyFood

// Recipe text scraped from websites carries raw HTML fragments —
// block tags and entities — that the app rendered verbatim. All cases below
// with literal entities/tags occur in real source data (seed files exported
// from a website, or JSON-LD scraped from recipe pages).
final class RecipeTextCleanerTests: XCTestCase {

    // MARK: — Tags

    func test_strips_paragraph_wrapper() {
        XCTAssertEqual("<p>Feiner Milchreis mit Mandelmilch.</p>".cleanedRecipeText,
                       "Feiner Milchreis mit Mandelmilch.")
    }

    func test_converts_inner_paragraph_breaks_to_blank_line() {
        XCTAssertEqual("<p>Erster Absatz.</p><p>Zweiter Absatz.</p>".cleanedRecipeText,
                       "Erster Absatz.\n\nZweiter Absatz.")
    }

    func test_converts_br_variants_to_newline() {
        XCTAssertEqual("Zeile eins<br>Zeile zwei<br />Zeile drei".cleanedRecipeText,
                       "Zeile eins\nZeile zwei\nZeile drei")
    }

    func test_strips_inline_tags_without_adding_spaces() {
        XCTAssertEqual("ein <strong>tolles</strong> Rezept mit <em>Liebe</em>".cleanedRecipeText,
                       "ein tolles Rezept mit Liebe")
    }

    func test_keeps_a_less_than_sign_that_is_not_a_tag() {
        XCTAssertEqual("Ich <3 Pasta in < 20 Minuten".cleanedRecipeText,
                       "Ich <3 Pasta in < 20 Minuten")
    }

    // MARK: — Entities

    func test_decodes_named_entities() {
        XCTAssertEqual("Mac &amp; Cheese".cleanedRecipeText, "Mac & Cheese")
        XCTAssertEqual("&quot;so-eine-Art&quot; Pizza".cleanedRecipeText, "\"so-eine-Art\" Pizza")
        XCTAssertEqual("Milchreis.&nbsp;Dazu Orangensauce".cleanedRecipeText,
                       "Milchreis. Dazu Orangensauce")
    }

    func test_decodes_decimal_and_hex_entities() {
        XCTAssertEqual("heute gibt&#039;s Tacos".cleanedRecipeText, "heute gibt's Tacos")
        XCTAssertEqual("probier&#x27; unsere Reispfanne".cleanedRecipeText,
                       "probier' unsere Reispfanne")
        XCTAssertEqual("Pasta &#8211; schnell gemacht".cleanedRecipeText,
                       "Pasta – schnell gemacht")
    }

    func test_decodes_german_named_entities() {
        XCTAssertEqual("K&uuml;rbis mit S&uuml;&szlig;kartoffeln und &Auml;pfeln".cleanedRecipeText,
                       "Kürbis mit Süßkartoffeln und Äpfeln")
    }

    func test_decodes_double_encoded_ampersand_once() {
        XCTAssertEqual("Fish &amp;amp; Chips".cleanedRecipeText, "Fish &amp; Chips")
    }

    // MARK: — Preservation

    func test_preserves_german_typography_and_emoji() {
        let text = "Gerösteter Blumenkohl mit Zatar – „unser Liebling“ 💚 (ä ö ü ß)"
        XCTAssertEqual(text.cleanedRecipeText, text)
    }

    func test_clean_text_is_unchanged() {
        let text = "Cremig und schnell."
        XCTAssertEqual(text.cleanedRecipeText, text)
    }

    // MARK: — Whitespace and invisibles

    func test_normalizes_nbsp_and_collapses_spaces() {
        XCTAssertEqual("Milchreis\u{00A0}mit   Vanille".cleanedRecipeText,
                       "Milchreis mit Vanille")
    }

    func test_removes_invisible_characters() {
        XCTAssertEqual("Kartoffel\u{00AD}gratin mit\u{200B} Käse\u{FFFD}".cleanedRecipeText,
                       "Kartoffelgratin mit Käse")
    }

    func test_trims_and_collapses_blank_lines() {
        XCTAssertEqual("  <p>Absatz eins.</p>\n\n\n<p>Absatz zwei.</p>  ".cleanedRecipeText,
                       "Absatz eins.\n\nAbsatz zwei.")
    }

    // MARK: — Draft-level cleaning (applied to LLM and JSON-LD import paths)

    func test_cleaningTexts_cleans_all_user_visible_draft_fields() {
        var draft = RecipeDraft()
        draft.title = "Mac &amp; Cheese"
        draft.summary = "<p>Cremig &amp; lecker.</p>"
        draft.ingredientGroups = [
            IngredientGroupDraft(name: "F&uuml;r die Sauce", ingredients: [
                RecipeIngredientDraft(amount: "200", unit: "g",
                                      name: "Cashewkerne&nbsp;(roh)", notes: "&quot;am besten frisch&quot;")
            ])
        ]

        let cleaned = draft.cleaningTexts()

        XCTAssertEqual(cleaned.title, "Mac & Cheese")
        XCTAssertEqual(cleaned.summary, "Cremig & lecker.")
        XCTAssertEqual(cleaned.ingredientGroups[0].name, "Für die Sauce")
        XCTAssertEqual(cleaned.ingredientGroups[0].ingredients[0].name, "Cashewkerne (roh)")
        XCTAssertEqual(cleaned.ingredientGroups[0].ingredients[0].notes, "\"am besten frisch\"")
    }
}
