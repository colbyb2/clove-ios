import Foundation
import GRDB

/// Collection of database migrations for the app
enum Migrations {
    /// All migrations in order they should be applied
    static let all: [Migration] = [
        InitialMigration()
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

// Extension to help with JSON encoding/decoding
extension Data {
    func toJSONString() -> String {
        return String(data: self, encoding: .utf8) ?? "{}"
    }
}
