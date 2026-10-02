import Foundation

/// One aggregated line in the Einkaufsliste — a single ingredient merged across every recipe
/// currently in the list. `id` is a stable key (normalized `name|unit`) so the same ingredient
/// keeps its identity across re-derivations (the list is rebuilt whenever the plan changes), which
/// is what lets a ticked checkbox survive a refresh.
struct ShoppingItem: Identifiable, Codable, Equatable {
    let id: String
    var name: String       // display name, first-seen casing
    var quantity: String   // display amount, e.g. "300 g" — empty when there's nothing to show
    var isChecked: Bool
}
