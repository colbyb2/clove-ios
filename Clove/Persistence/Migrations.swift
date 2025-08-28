import Foundation
import GRDB

/// Collection of database migrations for the app
enum Migrations {
    /// All migrations in order they should be applied
    static let all: [Migration] = [
        InitialMigration(),
        UserSettingsMigration(),
        SymptomIdMigration(),
        WeatherFieldMigration(),
        WeatherSettingMigration(),
        MedicationTrackingMigration(),
        NotesTrackingMigration(),
        BowelMovementSettingMigration(),
        BowelMovementTableMigration()
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

/// Migration to add symptom IDs to existing symptom ratings
struct SymptomIdMigration: Migration {
    var identifier: String {
        return "symptomId_062725"
    }
    
    func migrate(_ db: Database) throws {
        // Get all tracked symptoms to create a name-to-ID mapping
        let trackedSymptoms = try TrackedSymptom.fetchAll(db)
        let symptomNameToId = Dictionary(uniqueKeysWithValues: trackedSymptoms.map { ($0.name, $0.id ?? 0) })
        
        // Get all daily logs  
        let logs = try Row.fetchAll(db, sql: "SELECT id, symptomRatingsJSON FROM dailyLog").map { row in
            (id: row["id"] as Int64, symptomRatingsJSON: row["symptomRatingsJSON"] as String)
        }
        
        // Helper struct for legacy symptom rating (without ID)
        struct LegacySymptomRating: Codable {
            var symptomName: String
            var rating: Int
        }
        
        // Helper struct for new symptom rating (with ID)
        struct NewSymptomRating: Codable {
            var symptomId: Int64
            var symptomName: String
            var rating: Int
        }
        
        // Update each log's symptom ratings JSON
        for log in logs {
            guard let jsonData = log.symptomRatingsJSON.data(using: String.Encoding.utf8),
                  let legacyRatings = try? JSONDecoder().decode([LegacySymptomRating].self, from: jsonData) else {
                continue
            }
            
            // Convert legacy ratings to new format with IDs
            let newRatings = legacyRatings.map { legacyRating in
                NewSymptomRating(
                    symptomId: symptomNameToId[legacyRating.symptomName] ?? 0,
                    symptomName: legacyRating.symptomName,
                    rating: legacyRating.rating
                )
            }
            
            // Encode the new ratings back to JSON
            if let newJsonData = try? JSONEncoder().encode(newRatings),
               let newJsonString = String(data: newJsonData, encoding: .utf8) {
                try db.execute(sql: "UPDATE dailyLog SET symptomRatingsJSON = ? WHERE id = ?", 
                             arguments: [newJsonString, log.id])
            }
        }
    }
}

/// Migration to add weather field to DailyLog table
struct WeatherFieldMigration: Migration {
    var identifier: String {
        return "weatherField_122924"
    }
    
    func migrate(_ db: Database) throws {
        try db.alter(table: "dailyLog") { t in
            t.add(column: "weather", .text)
        }
    }
}

/// Migration to add weather tracking setting to UserSettings table
struct WeatherSettingMigration: Migration {
    var identifier: String {
        return "weatherSetting_122924"
    }
    
    func migrate(_ db: Database) throws {
        try db.alter(table: "userSettings") { t in
            t.add(column: "trackWeather", .boolean).notNull().defaults(to: true)
        }
    }
}

/// Migration to add medication tracking tables
struct MedicationTrackingMigration: Migration {
    var identifier: String {
        return "medicationTracking_123024"
    }
    
    func migrate(_ db: Database) throws {
        // Create TrackedMedication table
        try db.create(table: "trackedMedication") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("name", .text).notNull()
            t.column("dosage", .text).notNull()
            t.column("instructions", .text).notNull()
            t.column("isAsNeeded", .boolean).notNull().defaults(to: false)
        }
        
        // Create MedicationHistoryEntry table
        try db.create(table: "medicationHistoryEntry") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("medicationId", .integer).notNull()
            t.column("medicationName", .text).notNull()
            t.column("changeType", .text).notNull()
            t.column("changeDate", .date).notNull()
            t.column("oldValue", .text)
            t.column("newValue", .text)
            t.column("notes", .text)
        }
        
        // Add medicationAdherenceJSON column to DailyLog table
        try db.alter(table: "dailyLog") { t in
            t.add(column: "medicationAdherenceJSON", .text).notNull().defaults(to: "[]")
        }
    }
}

/// Migration to add notes tracking setting to UserSettings table
struct NotesTrackingMigration: Migration {
    var identifier: String {
        return "notesTracking_010725"
    }
    
    func migrate(_ db: Database) throws {
        try db.alter(table: "userSettings") { t in
            t.add(column: "trackNotes", .boolean).notNull().defaults(to: false)
        }
    }
}

/// Migration to add bowel movement tracking setting to UserSettings table
struct BowelMovementSettingMigration: Migration {
    var identifier: String {
        return "bowelMovementSetting_081925"
    }
    
    func migrate(_ db: Database) throws {
        try db.alter(table: "userSettings") { t in
            t.add(column: "trackBowelMovements", .boolean).notNull().defaults(to: false)
        }
    }
}

/// Migration to create BowelMovement table
struct BowelMovementTableMigration: Migration {
    var identifier: String {
        return "bowelMovementTable_081925"
    }
    
    func migrate(_ db: Database) throws {
        try db.create(table: "bowelMovement") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("type", .double).notNull()
            t.column("date", .date).notNull()
            t.column("notes", .text)
        }
    }
}

// Extension to help with JSON encoding/decoding
extension Data {
    func toJSONString() -> String {
        return String(data: self, encoding: .utf8) ?? "{}"
    }
}
