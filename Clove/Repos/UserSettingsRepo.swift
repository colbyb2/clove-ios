import Foundation
import GRDB

final class UserSettingsRepo {
    static let shared = UserSettingsRepo(databaseManager: DatabaseManager.shared)

    private let databaseManager: DatabaseManaging

    init(databaseManager: DatabaseManaging) {
        self.databaseManager = databaseManager
    }

    func getSettings() -> UserSettings? {
        do {
            return try databaseManager.read { db in
                try UserSettings.fetchOne(db)
            }
        } catch {
            print("Error loading settings: \(error)")
            return nil
        }
    }

    func saveSettings(_ settings: UserSettings) -> Bool {
        do {
            try databaseManager.write { db in
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
