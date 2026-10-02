import Foundation

struct KitaMealPlan: Codable, Identifiable, Equatable {
    struct Day: Codable, Equatable {
        let date: String?
        let meal: String?
        var mainIngredient: String? = nil
    }

    let id: UUID
    var childId: UUID?           // links to Child.id in UserSettings
    let weekOf: String?
    var monday: Day
    var tuesday: Day
    var wednesday: Day
    var thursday: Day
    var friday: Day

    init(id: UUID = UUID(), childId: UUID? = nil, weekOf: String? = nil,
         monday: Day = Day(date: nil, meal: nil),
         tuesday: Day = Day(date: nil, meal: nil),
         wednesday: Day = Day(date: nil, meal: nil),
         thursday: Day = Day(date: nil, meal: nil),
         friday: Day = Day(date: nil, meal: nil)) {
        self.id = id
        self.childId = childId
        self.weekOf = weekOf
        self.monday = monday
        self.tuesday = tuesday
        self.wednesday = wednesday
        self.thursday = thursday
        self.friday = friday
    }

    static let mock = KitaMealPlan(
        weekOf: "06.05.2026",
        monday:    Day(date: "06.05.2026", meal: "Spaghetti Bolognese",            mainIngredient: "Pasta"),
        tuesday:   Day(date: "07.05.2026", meal: "Gemüsesuppe mit Brot",           mainIngredient: "Gemüse"),
        wednesday: Day(date: "08.05.2026", meal: "Hähnchen mit Reis und Erbsen",   mainIngredient: "Fleisch"),
        thursday:  Day(date: "09.05.2026", meal: "Kartoffelgratin",                mainIngredient: "Kartoffeln"),
        friday:    Day(date: "10.05.2026", meal: "Fischstäbchen mit Kartoffelpüree", mainIngredient: "Fisch")
    )

    var days: [(name: String, date: String?, meal: String?)] {
        [
            ("Montag",     monday.date,    monday.meal),
            ("Dienstag",   tuesday.date,   tuesday.meal),
            ("Mittwoch",   wednesday.date, wednesday.meal),
            ("Donnerstag", thursday.date,  thursday.meal),
            ("Freitag",    friday.date,    friday.meal)
        ]
    }
}
