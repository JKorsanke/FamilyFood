import UIKit

/// Registers the bundled Inter / Inter Tight variable fonts.
///
/// The app also lists them under `UIAppFonts` (Info.plist) so they load at launch, but
/// `registerIfNeeded()` makes them available in SwiftUI #Previews and unit tests too, and is a
/// no-op when the family is already registered.
enum AppFonts {
    private static var didRun = false

    static func registerIfNeeded() {
        guard !didRun else { return }
        didRun = true
        register(resource: "Inter",      family: "Inter")
        register(resource: "InterTight", family: "Inter Tight")
        register(resource: "Gaegu-Bold", family: "Gaegu")
    }

    private static func register(resource: String, family: String) {
        // Already provided by UIAppFonts at launch? Nothing to do.
        if UIFont.familyNames.contains(family) { return }
        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: resource, withExtension: "ttf")
            ?? bundle.url(forResource: resource, withExtension: "ttf", subdirectory: "Fonts")
        else {
            assertionFailure("bundled font \(resource).ttf not found")
            return
        }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

private final class BundleToken {}
