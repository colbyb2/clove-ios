import Foundation
import GRDB
import SwiftUI

@Observable
class DataImportManager {
    static let shared = DataImportManager(
        databaseManager: DatabaseManager.shared,
        analyticsRevisionSource: AnalyticsRevisionSource.shared
    )

    private let databaseManager: DatabaseManaging
    private let analyticsRevisionSource: any AnalyticsRevisionProviding

    init(
        databaseManager: DatabaseManaging,
        analyticsRevisionSource: any AnalyticsRevisionProviding = AnalyticsRevisionSource.shared
    ) {
        self.databaseManager = databaseManager
        self.analyticsRevisionSource = analyticsRevisionSource
    }
    
    var isImporting: Bool = false
    var importProgress: Double = 0.0
    var importError: ImportError?
    
    func importFromCSV(
        fileURL: URL,
        completion: @escaping (Result<ImportResult, ImportError>) -> Void
    ) {
        isImporting = true
        importProgress = 0.0
        importError = nil
        
        Task {
            do {
                let result = try await performImport(from: fileURL)
                
                await MainActor.run {
                    self.isImporting = false
                    self.importProgress = 1.0
                    completion(.success(result))
                }
            } catch let error as ImportError {
                await MainActor.run {
                    self.isImporting = false
                    self.importError = error
                    completion(.failure(error))
                }
            } catch {
                await MainActor.run {
                    self.isImporting = false
                    let importError = ImportError.databaseError(error.localizedDescription)
                    self.importError = importError
                    completion(.failure(importError))
                }
            }
        }
    }
    
    func performImport(from fileURL: URL) async throws -> ImportResult {
        // Step 1: Parse CSV
        await updateProgress(0.1)
        let parsedData = try CSVParser.parseCSV(from: fileURL)
        
        // Step 2: Validate headers
        await updateProgress(0.2)
        try ImportValidator.validateHeaders(parsedData.headers)
        
        // Step 3: Extract symptom columns
        let symptomColumns = ImportValidator.extractSymptomColumns(from: parsedData.headers)
        
        // Step 4: Validate all rows
        await updateProgress(0.3)
        for (index, row) in parsedData.rows.enumerated() {
            try ImportValidator.validateRowData(row, headers: parsedData.headers, rowNumber: index + 2)
        }
        
        // Step 5: Perform atomic import
        await updateProgress(0.4)
        return try await performAtomicImport(parsedData: parsedData, symptomColumns: symptomColumns)
    }
    
    private func performAtomicImport(parsedData: ParsedCSVData, symptomColumns: [String]) async throws -> ImportResult {
        await updateProgress(0.5)

        let result = try databaseManager.writeReturning { db in
            try clearExistingData(in: db)

            let symptomImport = try createMissingSymptoms(symptomColumns, in: db)
            var importedLogsCount = 0
            var createdBowelMovementsCount = 0

            for row in parsedData.rows {
                let importedRow = try createImportedRow(
                    row: row,
                    columnMap: parsedData.columnMap,
                    symptomColumns: symptomColumns,
                    symptomIDsByName: symptomImport.idsByName
                )

                for entry in importedRow.foodEntries {
                    var identifiedEntry = entry
                    identifiedEntry.analyticsIdentityID = try DynamicMetricIdentityStore.resolveID(
                        family: .meal,
                        name: entry.name,
                        in: db
                    )
                    try identifiedEntry.insert(db)
                }

                for entry in importedRow.activityEntries {
                    var identifiedEntry = entry
                    identifiedEntry.analyticsIdentityID = try DynamicMetricIdentityStore.resolveID(
                        family: .activity,
                        name: entry.name,
                        in: db
                    )
                    try identifiedEntry.insert(db)
                }

                for movement in importedRow.bowelMovements {
                    try movement.insert(db)
                }

                try saveDailyLog(importedRow.dailyLog, in: db)
                importedLogsCount += 1
                createdBowelMovementsCount += importedRow.bowelMovements.count
            }

            return ImportResult(
                success: true,
                importedLogsCount: importedLogsCount,
                createdSymptomsCount: symptomImport.createdCount,
                createdBowelMovementsCount: createdBowelMovementsCount,
                skippedRowsCount: 0,
                errors: [],
                warnings: []
            )
        }

        analyticsRevisionSource.bump(reason: .dataImport)
        await updateProgress(1.0)
        return result
    }

    private func clearExistingData(in db: Database) throws {
        try db.execute(sql: "DELETE FROM dailyLog")
        try db.execute(sql: "DELETE FROM bowelMovement")
        try db.execute(sql: "DELETE FROM foodEntry")
        try db.execute(sql: "DELETE FROM activityEntry")

        // Symptoms and medications remain because CSV imports may reference
        // existing definitions that are not themselves fully represented in CSV.
    }

    private func createMissingSymptoms(
        _ symptomColumns: [String],
        in db: Database
    ) throws -> (createdCount: Int, idsByName: [String: Int64]) {
        let existingSymptoms = try TrackedSymptom.fetchAll(db)
        var idsByName = Dictionary(
            uniqueKeysWithValues: existingSymptoms.compactMap { symptom in
                symptom.id.map { (symptom.name, $0) }
            }
        )
        var createdCount = 0

        for symptomName in symptomColumns {
            if idsByName[symptomName] == nil {
                let newSymptom = TrackedSymptom(name: symptomName)
                try newSymptom.insert(db)
                let id = db.lastInsertedRowID
                idsByName[symptomName] = id
                try DynamicMetricIdentityStore.registerAlias(
                    family: .symptom,
                    sourceID: id,
                    name: symptomName,
                    in: db
                )
                createdCount += 1
            }
        }

        return (createdCount, idsByName)
    }

    private struct ImportedRow {
        let dailyLog: DailyLog
        let foodEntries: [FoodEntry]
        let activityEntries: [ActivityEntry]
        let bowelMovements: [BowelMovement]
    }

    private func createImportedRow(
        row: [String],
        columnMap: [String: Int],
        symptomColumns: [String],
        symptomIDsByName: [String: Int64]
    ) throws -> ImportedRow {
        
        // Parse date (required)
        guard let dateIndex = columnMap["Date"],
              let date = parseDate(row[dateIndex]) else {
            throw ImportError.invalidDateFormat(row[columnMap["Date"] ?? 0])
        }
        
        // Parse optional fields
        let mood = parseOptionalInt(getValue("Mood", row: row, columnMap: columnMap))
        let painLevel = parseOptionalInt(getValue("Pain Level", row: row, columnMap: columnMap))
        let energyLevel = parseOptionalInt(getValue("Energy Level", row: row, columnMap: columnMap))
        let waterIntake = parseOptionalInt(getValue("Hydration (oz)", row: row, columnMap: columnMap))
        let isFlareDay = parseFlareDay(getValue("Flare Day", row: row, columnMap: columnMap))
        let weather = getValue("Weather", row: row, columnMap: columnMap)
        
        // Parse list fields
        let medications = parseListField(getValue("Medications", row: row, columnMap: columnMap))
        let mealsData = getValue("Meals", row: row, columnMap: columnMap)
        let activitiesData = getValue("Activities", row: row, columnMap: columnMap)
        let notes = getValue("Notes", row: row, columnMap: columnMap)

        // Parse related entries without saving. Persistence happens only after
        // every mutation is inside the database transaction.
        let foodEntries = parseFoodEntries(mealsData, for: date)
        let activityEntries = parseActivityEntries(activitiesData, for: date)

        // Parse symptom ratings
        let symptomRatings = parseSymptomRatings(
            row: row,
            columnMap: columnMap,
            symptomColumns: symptomColumns,
            symptomIDsByName: symptomIDsByName
        )

        // Parse bowel movements and create them
        let bowelMovementsData = getValue("Bowel Movements", row: row, columnMap: columnMap)
        let bowelMovements = try parseBowelMovements(bowelMovementsData, for: date)

        // Create daily log (meals and activities are now in separate tables)
        let dailyLog = DailyLog(
            date: date,
            mood: mood,
            painLevel: painLevel,
            energyLevel: energyLevel,
            waterIntake: waterIntake,
            meals: [],
            activities: [],
            medicationsTaken: medications,
            medicationAdherence: [], // Not exported, so empty on import
            notes: notes.isEmpty ? nil : notes,
            isFlareDay: isFlareDay,
            weather: weather.isEmpty ? nil : weather,
            symptomRatings: symptomRatings
        )

        return ImportedRow(
            dailyLog: dailyLog,
            foodEntries: foodEntries,
            activityEntries: activityEntries,
            bowelMovements: bowelMovements
        )
    }

    private func saveDailyLog(_ log: DailyLog, in db: Database) throws {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: log.date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            throw ImportError.databaseError("Could not calculate the imported log date range")
        }

        if let existing = try DailyLog
            .filter(Column("date") >= startOfDay && Column("date") < endOfDay)
            .fetchOne(db) {
            var updated = log
            updated.id = existing.id
            try updated.update(db)
        } else {
            try log.insert(db)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getValue(_ column: String, row: [String], columnMap: [String: Int]) -> String {
        guard let index = columnMap[column], index < row.count else { return "" }
        return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func parseOptionalInt(_ value: String) -> Int? {
        guard !value.isEmpty else { return nil }
        return Int(value)
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.date(from: dateString)
    }
    
    private func parseFlareDay(_ value: String) -> Bool {
        return ["Yes", "true", "1"].contains(value)
    }
    
    private func parseListField(_ value: String) -> [String] {
        guard !value.isEmpty else { return [] }
        return value.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
    }
    
    private func parseSymptomRatings(
        row: [String],
        columnMap: [String: Int],
        symptomColumns: [String],
        symptomIDsByName: [String: Int64]
    ) -> [SymptomRating] {
        var ratings: [SymptomRating] = []

        for symptomName in symptomColumns {
            let value = getValue(symptomName, row: row, columnMap: columnMap)
            guard !value.isEmpty, let rating = Int(value) else { continue }

            if let symptomId = symptomIDsByName[symptomName] {
                ratings.append(SymptomRating(
                    symptomId: symptomId,
                    symptomName: symptomName,
                    rating: rating
                ))
            }
        }
        
        return ratings
    }
    
    private func parseBowelMovements(_ value: String, for date: Date) throws -> [BowelMovement] {
        guard !value.isEmpty else { return [] }
        
        var movements: [BowelMovement] = []
        let movementStrings = value.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        
        for movementString in movementStrings {
            // Parse "Type 3 (2:30 PM)" format
            guard movementString.hasPrefix("Type ") else { continue }
            
            let remaining = String(movementString.dropFirst(5)) // Remove "Type "
            guard let parenIndex = remaining.firstIndex(of: "(") else { continue }
            
            let typeString = String(remaining[..<parenIndex]).trimmingCharacters(in: .whitespaces)
            guard let type = Int(typeString), type >= 1 && type <= 7 else { continue }
            
            // Extract time
            let timeString = String(remaining[remaining.index(after: parenIndex)...])
                .replacingOccurrences(of: ")", with: "")
                .trimmingCharacters(in: .whitespaces)
            
            // Create date with time
            let movementDate = createDateWithTime(baseDate: date, timeString: timeString) ?? date
            
            movements.append(BowelMovement(
                type: Double(type), date: movementDate
            ))
        }
        
        return movements
    }
    
    private func createDateWithTime(baseDate: Date, timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        guard let time = formatter.date(from: timeString) else { return nil }

        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        return calendar.date(bySettingHour: timeComponents.hour ?? 0,
                           minute: timeComponents.minute ?? 0,
                           second: 0,
                           of: calendar.startOfDay(for: baseDate))
    }

    private func parseFoodEntries(_ value: String, for date: Date) -> [FoodEntry] {
        guard !value.isEmpty else { return [] }

        var entries: [FoodEntry] = []
        let foodStrings = value.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }

        for foodString in foodStrings {
            guard !foodString.isEmpty else { continue }

            // Parse "Salmon (Lunch)" format
            guard let parenIndex = foodString.firstIndex(of: "(") else {
                // No category, default to snack
                entries.append(FoodEntry(name: foodString, category: .snack, date: date))
                continue
            }

            let name = String(foodString[..<parenIndex]).trimmingCharacters(in: .whitespaces)
            let categoryString = String(foodString[foodString.index(after: parenIndex)...])
                .replacingOccurrences(of: ")", with: "")
                .trimmingCharacters(in: .whitespaces)

            // Map category display name to enum
            let category: MealCategory
            switch categoryString {
            case "Breakfast": category = .breakfast
            case "Lunch": category = .lunch
            case "Dinner": category = .dinner
            case "Snack": category = .snack
            case "Beverage": category = .beverage
            default: category = .snack
            }

            entries.append(FoodEntry(name: name, category: category, date: date))
        }

        return entries
    }

    private func parseActivityEntries(_ value: String, for date: Date) -> [ActivityEntry] {
        guard !value.isEmpty else { return [] }

        var entries: [ActivityEntry] = []
        let activityStrings = value.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }

        for activityString in activityStrings {
            guard !activityString.isEmpty else { continue }

            // Parse "Lift (Exercise)" format
            guard let parenIndex = activityString.firstIndex(of: "(") else {
                // No category, default to other
                entries.append(ActivityEntry(name: activityString, category: .other, date: date))
                continue
            }

            let name = String(activityString[..<parenIndex]).trimmingCharacters(in: .whitespaces)
            let categoryString = String(activityString[activityString.index(after: parenIndex)...])
                .replacingOccurrences(of: ")", with: "")
                .trimmingCharacters(in: .whitespaces)

            // Map category display name to enum
            let category: ActivityCategory
            switch categoryString {
            case "Exercise": category = .exercise
            case "Wellness": category = .wellness
            case "Social": category = .social
            case "Chores": category = .chores
            case "Rest": category = .rest
            case "Other": category = .other
            default: category = .other
            }

            entries.append(ActivityEntry(name: name, category: category, date: date))
        }

        return entries
    }

    @MainActor
    private func updateProgress(_ progress: Double) {
        self.importProgress = progress
    }
}
