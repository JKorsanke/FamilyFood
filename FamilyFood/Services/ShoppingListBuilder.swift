import Foundation

/// Aggregates the ingredients of a set of recipes into a flat, de-duplicated shopping list.
/// Pure and stateless — the single source of truth for "what's on the list" is the set of
/// recipes handed in (derived from the current week's plan); this just merges their ingredients.
enum ShoppingListBuilder {

    /// Merge every recipe's ingredients into one list: same name + unit collapse into a single
    /// line (amounts summed when numeric), different units stay separate, sorted alphabetically.
    static func aggregate(_ recipes: [RecipeModel]) -> [ShoppingItem] {
        var order: [String] = []                 // keys in first-seen order (display only)
        var bins: [String: Bin] = [:]

        for recipe in recipes {
            for group in recipe.ingredientGroups.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                for ing in group.ingredients.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                    let name = ing.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { continue }          // unnamed line — nothing to buy
                    let unit = ing.unit.trimmingCharacters(in: .whitespacesAndNewlines)
                    let key = "\(name.lowercased())|\(unit.lowercased())"
                    if bins[key] == nil {
                        bins[key] = Bin(name: name, unit: unit)
                        order.append(key)
                    }
                    let amount = ing.amount.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !amount.isEmpty { bins[key]?.amounts.append(amount) }
                }
            }
        }

        return order
            .map { key -> ShoppingItem in
                let bin = bins[key]!
                return ShoppingItem(id: key, name: bin.name, quantity: bin.quantity, isChecked: false)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // MARK: - Aggregation bin

    private struct Bin {
        let name: String
        let unit: String
        var amounts: [String] = []

        /// "300 g", "etwas + 1 Prise", or "" — amounts are summed when every one parses as a
        /// number, otherwise listed verbatim so nothing is silently dropped.
        var quantity: String {
            let amountText: String
            if amounts.isEmpty {
                amountText = ""
            } else if let sum = summedAmount() {
                amountText = ShoppingListBuilder.format(sum)
            } else {
                amountText = amounts.joined(separator: " + ")
            }
            return [amountText, unit].filter { !$0.isEmpty }.joined(separator: " ")
        }

        /// Sum of all amounts, or nil if any one is non-numeric.
        private func summedAmount() -> Double? {
            var total = 0.0
            for raw in amounts {
                guard let value = ShoppingListBuilder.parseAmount(raw) else { return nil }
                total += value
            }
            return total
        }
    }

    // MARK: - Number parsing & formatting

    /// Parses "200", "0,5" (German decimal), or "1/2" (simple fraction) to a Double. nil otherwise.
    static func parseAmount(_ raw: String) -> Double? {
        let normalized = raw.replacingOccurrences(of: ",", with: ".")
        if let value = Double(normalized) { return value }
        let parts = normalized.split(separator: "/")
        if parts.count == 2,
           let numerator = Double(parts[0]),
           let denominator = Double(parts[1]),
           denominator != 0 {
            return numerator / denominator
        }
        return nil
    }

    /// Whole numbers print without decimals ("300"); fractions trim trailing zeros and use a
    /// German decimal comma ("0,5", "1,25").
    static func format(_ value: Double) -> String {
        if value == value.rounded() { return String(Int(value)) }
        var text = String(format: "%.2f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text.replacingOccurrences(of: ".", with: ",")
    }
}
