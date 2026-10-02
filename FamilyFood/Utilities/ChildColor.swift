import SwiftUI

/// Stable color assignment for a child's Kita pill in the meal-plan overview.
///
/// Must be deterministic across app launches. `UUID.hashValue` is **not** — Swift seeds
/// `Hashable` with a per-process random value, so hashing the same id yields a different
/// bucket each launch. We derive the index from the raw UUID bytes instead, so a child
/// keeps the same color after the app is reopened.
enum ChildColor {
    static let palette: [Color] = [.orange, .blue, .green]

    static func index(for id: UUID) -> Int {
        let u = id.uuid
        let sum = [u.0, u.1, u.2, u.3, u.4, u.5, u.6, u.7,
                   u.8, u.9, u.10, u.11, u.12, u.13, u.14, u.15]
            .reduce(0) { $0 + Int($1) }
        return sum % palette.count
    }

    static func color(for id: UUID) -> Color { palette[index(for: id)] }
}
