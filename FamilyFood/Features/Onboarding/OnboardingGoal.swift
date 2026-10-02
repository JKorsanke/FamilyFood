import Foundation

/// Priorities shown on onboarding screen 01 (Goals). Multi-select and **not persisted**:
/// a transient priority signal only — no goal changes `UserSettings` (cook time now defaults to
/// ≤30 Min for everyone). Lives in the Onboarding feature rather than `Models/` because it never
/// reaches `UserSettings`. Cases are in display order.
enum OnboardingGoal: CaseIterable, Hashable {
    case schnelleZubereitung
    case planbarkeit
    case gesundeErnaehrung
    case abwechslung
    case alleWerdenSatt
    case saisonaleGerichte

    var displayName: String {
        switch self {
        case .schnelleZubereitung: return "Schnelle Zubereitung"
        case .planbarkeit:         return "Planbarkeit"
        case .gesundeErnaehrung:   return "Gesunde Ernährung"
        case .abwechslung:         return "Abwechselung"
        case .alleWerdenSatt:      return "Alle werden satt"
        case .saisonaleGerichte:   return "Saisonale Gerichte"
        }
    }
}
