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
        BowelMovementTableMigration(),
        BinarySymptomMigration(),
        FoodActivityTablesMigration(),
        FoodActivityDataMigration(),
        CycleTableMigration(),
        CycleSettingMigration()
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

/// Migration to add isBinary field to symptoms
struct BinarySymptomMigration: Migration {
    var identifier: String {
        return "binarySymptom_120325"
    }

    func migrate(_ db: Database) throws {
        // Add isBinary column to TrackedSymptom table
        try db.alter(table: "trackedSymptom") { t in
            t.add(column: "isBinary", .boolean).notNull().defaults(to: false)
        }
    }
}

// Extension to help with JSON encoding/decoding
extension Data {
    func toJSONString() -> String {
        return String(data: self, encoding: .utf8) ?? "{}"
    }
}

/// Migration to create FoodEntry and ActivityEntry tables
struct FoodActivityTablesMigration: Migration {
    var identifier: String {
        return "foodActivityTables_012725"
    }

    func migrate(_ db: Database) throws {
        // Create FoodEntry table
        try db.create(table: "foodEntry") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("name", .text).notNull()
            t.column("category", .text).notNull()
            t.column("date", .datetime).notNull()
            t.column("icon", .text)
            t.column("notes", .text)
            t.column("isFavorite", .boolean).notNull().defaults(to: false)
        }

        // Create ActivityEntry table
        try db.create(table: "activityEntry") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("name", .text).notNull()
            t.column("category", .text).notNull()
            t.column("date", .datetime).notNull()
            t.column("duration", .integer)
            t.column("intensity", .text)
            t.column("icon", .text)
            t.column("notes", .text)
            t.column("isFavorite", .boolean).notNull().defaults(to: false)
        }

        // Create indexes for efficient date-based queries
        try db.create(index: "foodEntry_date", on: "foodEntry", columns: ["date"])
        try db.create(index: "activityEntry_date", on: "activityEntry", columns: ["date"])
    }
}

/// Migration to convert existing meals/activities string arrays to new entry tables
struct FoodActivityDataMigration: Migration {
    var identifier: String {
        return "foodActivityData_012725"
    }

    func migrate(_ db: Database) throws {
        // Get all daily logs with meals or activities
        let logs = try Row.fetchAll(db, sql: """
            SELECT id, date, meals, activities FROM dailyLog
            WHERE meals != '[]' OR activities != '[]'
        """)

        for log in logs {
            let logDate: Date = log["date"]
            let mealsJSON: String = log["meals"]
            let activitiesJSON: String = log["activities"]

            // Parse meals JSON array
            if let mealsData = mealsJSON.data(using: .utf8),
               let meals = try? JSONDecoder().decode([String].self, from: mealsData) {
                for meal in meals {
                    // Infer category based on common meal names
                    let category = inferMealCategory(from: meal)

                    try db.execute(sql: """
                        INSERT INTO foodEntry (name, category, date, isFavorite)
                        VALUES (?, ?, ?, 0)
                    """, arguments: [meal, category.rawValue, logDate])
                }
            }

            // Parse activities JSON array
            if let activitiesData = activitiesJSON.data(using: .utf8),
               let activities = try? JSONDecoder().decode([String].self, from: activitiesData) {
                for activity in activities {
                    // Infer category based on common activity names
                    let category = inferActivityCategory(from: activity)

                    try db.execute(sql: """
                        INSERT INTO activityEntry (name, category, date, isFavorite)
                        VALUES (?, ?, ?, 0)
                    """, arguments: [activity, category.rawValue, logDate])
                }
            }
        }
    }

    /// Infers the meal category based on the meal name
    private func inferMealCategory(from name: String) -> MealCategory {
        let lowercased = name.lowercased()

        // Check for explicit meal type names
        if lowercased.contains("breakfast") || lowercased.contains("cereal") ||
            lowercased.contains("oatmeal") || lowercased.contains("pancake") ||
            lowercased.contains("waffle") || lowercased.contains("eggs") {
            return .breakfast
        }

        if lowercased.contains("lunch") || lowercased.contains("sandwich") ||
            lowercased.contains("wrap") || lowercased.contains("salad") {
            return .lunch
        }

        if lowercased.contains("dinner") || lowercased.contains("supper") {
            return .dinner
        }

        if lowercased.contains("snack") || lowercased.contains("chips") ||
            lowercased.contains("cookie") || lowercased.contains("fruit") ||
            lowercased.contains("nuts") || lowercased.contains("candy") ||
            lowercased.contains("chocolate") {
            return .snack
        }

        if lowercased.contains("coffee") || lowercased.contains("tea") ||
            lowercased.contains("water") || lowercased.contains("juice") ||
            lowercased.contains("soda") || lowercased.contains("smoothie") ||
            lowercased.contains("milk") || lowercased.contains("drink") {
            return .beverage
        }

        // Default to snack for unrecognized items
        return .snack
    }

    /// Infers the activity category based on the activity name
    private func inferActivityCategory(from name: String) -> ActivityCategory {
        let lowercased = name.lowercased()

        // Exercise activities
        if lowercased.contains("run") || lowercased.contains("walk") ||
            lowercased.contains("gym") || lowercased.contains("workout") ||
            lowercased.contains("swim") || lowercased.contains("cycling") ||
            lowercased.contains("bike") || lowercased.contains("hike") ||
            lowercased.contains("jog") || lowercased.contains("exercise") ||
            lowercased.contains("lift") || lowercased.contains("cardio") ||
            lowercased.contains("sport") || lowercased.contains("tennis") ||
            lowercased.contains("basketball") || lowercased.contains("soccer") ||
            lowercased.contains("football") || lowercased.contains("dance") {
            return .exercise
        }

        // Wellness activities
        if lowercased.contains("yoga") || lowercased.contains("meditat") ||
            lowercased.contains("stretch") || lowercased.contains("relax") ||
            lowercased.contains("therapy") || lowercased.contains("massage") ||
            lowercased.contains("spa") || lowercased.contains("mindful") {
            return .wellness
        }

        // Social activities
        if lowercased.contains("friend") || lowercased.contains("family") ||
            lowercased.contains("party") || lowercased.contains("dinner") ||
            lowercased.contains("lunch") || lowercased.contains("meeting") ||
            lowercased.contains("visit") || lowercased.contains("hangout") ||
            lowercased.contains("date") || lowercased.contains("call") {
            return .social
        }

        // Chores/household activities
        if lowercased.contains("clean") || lowercased.contains("laundry") ||
            lowercased.contains("cook") || lowercased.contains("shop") ||
            lowercased.contains("grocery") || lowercased.contains("errand") ||
            lowercased.contains("chore") || lowercased.contains("dishes") ||
            lowercased.contains("vacuum") || lowercased.contains("organizing") {
            return .chores
        }

        // Rest activities
        if lowercased.contains("rest") || lowercased.contains("nap") ||
            lowercased.contains("sleep") || lowercased.contains("relax") ||
            lowercased.contains("tv") || lowercased.contains("movie") ||
            lowercased.contains("reading") || lowercased.contains("read") {
            return .rest
        }

        // Default to other for unrecognized activities
        return .other
    }
}

/// Migration to create Cycle table for period tracking
struct CycleTableMigration: Migration {
    var identifier: String {
        return "cycleTable_020126"
    }

    func migrate(_ db: Database) throws {
        try db.create(table: "cycle") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("date", .date).notNull()
            t.column("flow", .text).notNull()
            t.column("isStartOfCycle", .boolean).notNull().defaults(to: false)
            t.column("hasCramps", .boolean).notNull().defaults(to: false)
        }

        // Create index for efficient date-based queries
        try db.create(index: "cycle_date", on: "cycle", columns: ["date"])
    }
}

/// Migration to add cycle tracking setting to UserSettings table
struct CycleSettingMigration: Migration {
    var identifier: String {
        return "cycleSetting_020126"
    }

    func migrate(_ db: Database) throws {
        try db.alter(table: "userSettings") { t in
            t.add(column: "trackCycle", .boolean).notNull().defaults(to: false)
        }
    }
}
