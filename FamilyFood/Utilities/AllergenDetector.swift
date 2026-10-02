import Foundation

// Keyword-based allergen detection from ingredient name strings.
// Used for seeded recipes (no LLM call at seed time).
//
// Keywords match as substrings on purpose: German compounds (Vollkornmehl,
// Sojaschnetzel) must hit their root keyword, so word-boundary matching would
// cost recall. The exception is "ei", a substring of half the vocabulary
// (Reis, Eis, Weintrauben) — it only counts as a standalone word or a
// compound suffix (Spiegelei, Rührei).
func inferAllergenTags(from ingredientNames: [String]) -> [String] {
    let names = ingredientNames.map { $0.lowercased() }
    var tags: [String] = []

    let checks: [(tag: String, keywords: [String])] = [
        ("Gluten",       ["mehl", "weizen", "dinkel", "roggen", "gerste", "hafer", "grieß",
                          "nudel", "pasta", "spaghetti", "penne", "brot", "semmel", "gebäck",
                          "couscous", "bulgur", "paniermehl", "semmelbrösel"]),
        ("Milch",        ["milch", "butter", "sahne", "käse", "joghurt", "mozzarella",
                          "parmesan", "cheddar", "gouda", "frischkäse", "quark",
                          "mascarpone", "ricotta", "schmand", "rahm"]),
        ("Ei",           ["ei", "eier", "eigelb", "eiweiß", "mayonnaise"]),
        ("Nüsse",        ["mandel", "walnuss", "walnüsse", "haselnuss", "haselnüsse",
                          "cashew", "pistazie", "pekannuss", "pinienkern", "nussmix"]),
        ("Erdnüsse",     ["erdnuss", "erdnüsse", "erdnussbutter"]),
        ("Fisch",        ["fisch", "lachs", "thunfisch", "kabeljau", "forelle",
                          "sardine", "hering", "makrele", "tilapia", "pangasius"]),
        ("Schalentiere", ["garnele", "garnelen", "shrimp", "krabbe", "krabben",
                          "muschel", "muscheln", "hummer"]),
        ("Soja",         ["soja", "tofu", "sojasoße", "sojasauce", "tamari", "miso",
                          "tempeh", "edamame", "sojasprossen", "sojajoghurt", "sojamilch"]),
        ("Sesam",        ["sesam", "tahini"]),
        ("Sellerie",     ["sellerie"]),
        ("Senf",         ["senf", "dijon"]),
    ]

    func matches(_ keyword: String, in name: String) -> Bool {
        if keyword == "ei" {
            return name.hasSuffix("ei") || name.contains("ei ")
        }
        return name.contains(keyword)
    }

    for check in checks {
        if check.keywords.contains(where: { kw in names.contains { matches(kw, in: $0) } }) {
            tags.append(check.tag)
        }
    }
    return tags
}
