import CoreGraphics

/// Swappable source of truth for the Wochenplan "Generieren" toolbar glyph.
///
/// The whisk is the active icon; the spoon stays in the catalog as the
/// prepared alternative, so switching is a one-line change to `current` — no new art, no layout
/// work (each art's fit-size lives here, not at the call site).
enum MealPlanGenerateIcon {
    case spoon, whisk

    static let current: MealPlanGenerateIcon = .whisk   // .spoon is the prepared alternative

    var assetName: String {
        switch self {
        case .spoon: "ic-generate-spoon"
        case .whisk: "ic-generate-whisk"
        }
    }

    /// Fit within a 40-pt box (each art has its own aspect ratio).
    var size: CGSize {
        switch self {
        case .spoon: CGSize(width: 40, height: 39)
        case .whisk: CGSize(width: 28, height: 40)
        }
    }
}
