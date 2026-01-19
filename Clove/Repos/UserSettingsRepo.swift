import Foundation
import GRDB

class UserSettingsRepo {
    static let shared = UserSettingsRepo()

    private let dbManager = DatabaseManager.shared

    func getSettings() -> UserSettings? {
        do {
            return try dbManager.read { db in
                try UserSettings.fetchOne(db)
            }
        } catch {
            print("Error loading settings: \(error)")
            return nil
        }
    }

    func saveSettings(_ settings: UserSettings) -> Bool {
        do {
            try dbManager.write { db in
                try settings.save(db)
            }
            return true
        } catch {
            print("Error saving settings: \(error)")
            return false
        }
    }
}

// MARK: - Protocol Conformance
extension UserSettingsRepo: UserSettingsRepositoryProtocol {}