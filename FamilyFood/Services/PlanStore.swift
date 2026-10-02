import Foundation

/// On-device JSON persistence for weekly meal plans and Kita plans (no cloud, per the
/// app's on-device-only constraint). Files live in Application Support by default; tests
/// inject a temporary directory. The data types stay plain Codable value structs.
struct PlanStore {
    private let weeklyPlansURL: URL
    private let kitaPlansURL: URL

    /// Test/injection initializer — `directory` is any writable directory.
    init(directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        weeklyPlansURL = directory.appendingPathComponent("weekly_plans.json")
        kitaPlansURL = directory.appendingPathComponent("kita_plans.json")
    }

    /// Production initializer — `<Application Support>/MealPlans`.
    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.init(directory: base.appendingPathComponent("MealPlans", isDirectory: true))
    }

    func loadWeeklyPlans() -> [WeeklyPlan] { load(weeklyPlansURL) }
    func saveWeeklyPlans(_ plans: [WeeklyPlan]) { save(plans, to: weeklyPlansURL) }

    func loadKitaPlans() -> [KitaMealPlan] { load(kitaPlansURL) }
    func saveKitaPlans(_ plans: [KitaMealPlan]) { save(plans, to: kitaPlansURL) }

    // MARK: - Helpers

    /// Element-tolerant load: a single malformed record is dropped (and logged) instead of
    /// wiping the whole file's contents. Whenever anything was unreadable, the raw file is
    /// copied to `<name>.backup.json` first — the next `save` overwrites the original, and
    /// without the backup that overwrite would permanently destroy the user's history.
    private func load<T: Decodable>(_ url: URL) -> [T] {
        guard let data = try? Data(contentsOf: url) else { return [] }   // no file yet

        if let wrapped = try? JSONDecoder().decode([FailableDecodable<T>].self, from: data) {
            let values = wrapped.compactMap(\.value)
            if values.count < wrapped.count {
                Log.persistence.error("\(url.lastPathComponent): dropped \(wrapped.count - values.count) of \(wrapped.count) records as undecodable — backing up the original file")
                backUp(url)
            }
            return values
        }

        Log.persistence.error("\(url.lastPathComponent): file is not a decodable JSON array — backing up and starting empty")
        backUp(url)
        return []
    }

    private func backUp(_ url: URL) {
        let backupURL = url.deletingPathExtension().appendingPathExtension("backup.json")
        do {
            if FileManager.default.fileExists(atPath: backupURL.path) {
                try FileManager.default.removeItem(at: backupURL)
            }
            try FileManager.default.copyItem(at: url, to: backupURL)
        } catch {
            Log.persistence.error("\(url.lastPathComponent): backup failed: \(error.localizedDescription)")
        }
    }

    private func save<T: Encodable>(_ value: [T], to url: URL) {
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            Log.persistence.error("\(url.lastPathComponent): save failed: \(error.localizedDescription)")
        }
    }
}

/// Decodes to `nil` instead of failing the surrounding collection when one element
/// can't be decoded (e.g. a record written by a newer/older schema).
private struct FailableDecodable<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? decoder.singleValueContainer().decode(T.self)
    }
}
