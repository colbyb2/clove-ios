import Foundation
import GRDB

final class UserSettingsRepo {
    static let shared = UserSettingsRepo(databaseManager: DatabaseManager.shared)

    private let databaseManager: DatabaseManaging
    private let analyticsRevisionSource: any AnalyticsRevisionProviding

    init(
        databaseManager: DatabaseManaging,
        analyticsRevisionSource: any AnalyticsRevisionProviding = AnalyticsRevisionSource.shared
    ) {
        self.databaseManager = databaseManager
        self.analyticsRevisionSource = analyticsRevisionSource
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
            let previous = try databaseManager.read { db in
                try UserSettings.fetchOne(db)
            }
            try databaseManager.write { db in
                try settings.save(db)
            }
            if previous?.analyticsFingerprint != settings.analyticsFingerprint {
                analyticsRevisionSource.bump(reason: .analyticSettings)
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

private extension UserSettings {
    var analyticsFingerprint: [Bool] {
        [
            trackMood, trackPain, trackEnergy, trackHydration, trackSymptoms, trackMeals,
            trackActivities, trackMeds, showFlareToggle, trackWeather, trackBowelMovements, trackCycle
        ]
    }
}
