import Foundation

/// Every onboarding string in one place. Decision (2026-06-11): a caseless-`enum`
/// namespace, screens as data + one-off labels as constants; views render from this, no inline
/// strings. Option labels reuse existing model helpers (`DietStyle`, `allAllergens`, `Weekday`)
/// rather than duplicate them. Migrates mechanically to a String Catalog if we localize later.
enum OnboardingCopy {

    // MARK: - Shared action labels (data steps)
    static let weiter = "Weiter"
    static let ueberspringen = "Überspringen"

    /// Title + subtitle for the five data steps (01–05), in flow order. Drives the screen titles
    /// and lets the container show the right header for each step.
    struct Page {
        let title: String
        let subtitle: String?
        let illustration: String   // Asset-catalog name for the step's hero illustration
    }
    static let dataSteps: [Page] = [
        Page(title: "Was ist dir bei der Essensplanung wichtig?", subtitle: nil,
             illustration: "onb-01-goals"),
        Page(title: "Wer isst mit?", subtitle: "Damit die Portionen in den Rezepten passen.",
             illustration: "onb-02-household"),
        Page(title: "Wie ernährt ihr euch?", subtitle: "Wir schlagen passende Gerichte vor.",
             illustration: "onb-03-diet"),
        Page(title: "Gibt es Allergien?", subtitle: "Wir blenden passende Zutaten aus.",
             illustration: "onb-04-allergens"),
        Page(title: "Wann esst ihr warm?", subtitle: "An diesen Tagen planen wir eine warme Mahlzeit.",
             illustration: "onb-05-warmmeals")
    ]

    // MARK: - 00 Willkommen
    enum Welcome {
        static let headline = "Euer Familienessen, clever geplant."
        static let subhead  = "Plane die Woche in Minuten – ausgewogen, abwechslungsreich und ohne Dopplung mit dem Kita-Essen."
        static let benefits: [(icon: String, label: String)] = [
            ("calendar",   "Wochenplan ohne Kopfzerbrechen"),
            ("fork.knife", "Kein Gericht doppelt zum Kita-Essen"),
            ("cart",       "Einkaufsliste entsteht automatisch")
        ]
        static let primary = "Los geht's"
    }

    // MARK: - 02 Haushalt
    enum Household {
        static let adults      = "Erwachsene"
        static let adultsAge   = "13+ Jahre"
        static let children    = "Kind(er)"
        static let childrenAge = "0–12 Jahre"
        // Hard line break after "den" so the centered hint wraps to two balanced lines.
        static let namesHint   = "Du kannst später Namen in den\nEinstellungen hinzufügen."
    }

    // MARK: - 04 Allergene
    enum Allergens {
        static let none      = "Keine"
        static let microcopy = "Bitte prüfe bei Allergien immer die Produktangaben auf mögliche Spuren."
    }

    // MARK: - 05 Warme Mahlzeiten
    enum WarmMeals {
        /// e.g. "5 Tage ausgewählt · jederzeit änderbar" (singular "1 Tag").
        static func selectedSummary(_ count: Int) -> String {
            let tage = count == 1 ? "1 Tag" : "\(count) Tage"
            return "\(tage) ausgewählt · jederzeit änderbar"
        }
    }

    // MARK: - 06 Startpunkt
    enum Ready {
        static let eyebrow  = "Deine Angaben"
        static let headline = "Wir sind startklar"
        static let subtext  = "Wir nutzen deine Angaben, um dir pro Woche passende Gerichte vorzuschlagen."
    }

    // MARK: - 07 Womit starten?
    enum NextAction {
        static let title         = "Womit möchtest du starten?"
        static let subtitle      = "Lade einen Speiseplan aus der Schule, Kindergarten, Krippe hoch, oder teile dein Lieblingsrezept mit uns."
        static let kitaTitle     = "Kita-Plan hochladen"
        static let kitaSubtitle  = "Fotografiere den Speiseplan – wir übernehmen ihn automatisch."
        static let kitaIcon      = "camera"
        static let recipeTitle   = "Rezept hinzufügen"
        static let recipeSubtitle = "Füge ein Lieblingsrezept hinzu."
        static let recipeIcon    = "fork.knife"
        static let later         = "Lieber später · Ab zum Wochenplan"
    }
}
