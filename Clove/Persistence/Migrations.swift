import Foundation
import GRDB

/// Collection of database migrations for the app
enum Migrations {
    /// All migrations in order they should be applied
    static let all: [Migration] = [
        InitialMigration(),
        UserSettingsMigration()
    ]
}

/// The initial database migration that creates the core tables
struct InitialMigration: Migration {
    var identifier: String {
        return "initial"
    }
    
    func migrate(_ db: Database) throws {
        // Create DailyLog table
        try db.create(table: "dailyLog") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("date", .date).notNull()
            t.column("mood", .integer)
            t.column("painLevel", .integer)
            t.column("energyLevel", .integer)
            t.column("meals", .text).notNull()
            t.column("activities", .text).notNull()
            t.column("medicationsTaken", .text).notNull()
            t.column("notes", .text)
            t.column("isFlareDay", .boolean).notNull()
            t.column("symptomRatingsJSON", .text).notNull()
        }
        
        // Create TrackedSymptom table
        try db.create(table: "trackedSymptom") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("name", .text).notNull()
            t.column("order", .integer).notNull()
        }
    }
}

/// The migration for the user settings table
struct UserSettingsMigration: Migration {
    var identifier: String {
        return "userSettings_061825"
    }
    
    func migrate(_ db: Database) throws {
        try db.create(table: "userSettings") { t in
            t.column("id", .integer).primaryKey().defaults(to: 1)
            t.column("trackMood", .boolean).notNull().defaults(to: true)
            t.column("trackPain", .boolean).notNull().defaults(to: true)
            t.column("trackEnergy", .boolean).notNull().defaults(to: false)
            t.column("trackSymptoms", .boolean).notNull().defaults(to: true)
            t.column("trackMeals", .boolean).notNull().defaults(to: false)
            t.column("trackActivities", .boolean).notNull().defaults(to: false)
            t.column("trackMeds", .boolean).notNull().defaults(to: false)
            t.column("showFlareToggle", .boolean).notNull().defaults(to: true)
        }

        try db.execute(sql: """
            INSERT INTO userSettings (id, trackMood, trackPain, trackEnergy, trackSymptoms, trackMeals, trackActivities, trackMeds, showFlareToggle)
            VALUES (1, 1, 1, 0, 1, 0, 0, 0, 1)
        """)
    }
}

// Extension to help with JSON encoding/decoding
extension Data {
    func toJSONString() -> String {
        return String(data: self, encoding: .utf8) ?? "{}"
    }
}
