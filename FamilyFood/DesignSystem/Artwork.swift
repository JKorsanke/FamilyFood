import UIKit

/// Resolves illustration and brand-mark asset names.
///
/// The repository ships simple placeholder art under each base name. A build may also
/// bundle original artwork that cannot be redistributed, in a local, untracked asset
/// catalog (`LocalOverlay/Artwork.xcassets`) under the `local/` namespace; when an
/// original exists for a name it takes precedence.
enum Artwork {
    static let localNamespace = "local"

    /// The asset name to load for `base` in the running app.
    static func name(_ base: String) -> String {
        name(base, exists: { UIImage(named: $0) != nil })
    }

    /// Pure resolution rule; `exists` answers whether an asset name is in the catalog.
    static func name(_ base: String, exists: (String) -> Bool) -> String {
        let local = "\(localNamespace)/\(base)"
        return exists(local) ? local : base
    }
}
