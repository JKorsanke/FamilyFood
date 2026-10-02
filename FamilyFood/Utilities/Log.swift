import Foundation
import os

/// Central `os.Logger` instances, one per area, so failures that used to vanish in
/// `try?` are at least visible in Console.app (subsystem = bundle id).
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "familyfood"

    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let importing   = Logger(subsystem: subsystem, category: "import")
    static let engine      = Logger(subsystem: subsystem, category: "engine")
}
