import Foundation
import SwiftUI

@Observable
class DataImportManager {
    static let shared = DataImportManager()
    
    private init() {}
    
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
    
    private func performImport(from fileURL: URL) async throws -> ImportResult {
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
        var importedLogsCount = 0
        var createdSymptomsCount = 0
        var createdBowelMovementsCount = 0
        var skippedRowsCount = 0
        var warnings: [String] = []
        
        // Step 1: Clear existing data (as warned)
        await updateProgress(0.5)
        try clearExistingData()
        
        // Step 2: Create symptoms that don't exist
        await updateProgress(0.6)
        createdSymptomsCount = try createMissingSymptoms(symptomColumns)
        
        // Step 3: Import logs
        await updateProgress(0.7)
        let totalRows = parsedData.rows.count
        
        for (index, row) in parsedData.rows.enumerated() {
            do {
                let (dailyLog, bowelMovementCount) = try createDailyLogFromRow(
                    row: row, 
                    headers: parsedData.headers, 
                    columnMap: parsedData.columnMap,
                    symptomColumns: symptomColumns
                )
                
                // Save the daily log
                if LogsRepo.shared.saveLog(dailyLog) {
                    importedLogsCount += 1
                    createdBowelMovementsCount += bowelMovementCount
                } else {
                    skippedRowsCount += 1
                    warnings.append("Failed to save log for date: \(dailyLog.date)")
                }
                
                // Update progress
                let rowProgress = 0.7 + (Double(index + 1) / Double(totalRows)) * 0.3
                await updateProgress(rowProgress)
                
            } catch {
                skippedRowsCount += 1
                warnings.append("Skipped row \(index + 2): \(error.localizedDescription)")
            }
        }
        
        await updateProgress(1.0)
        
        return ImportResult(
            success: true,
            importedLogsCount: importedLogsCount,
            createdSymptomsCount: createdSymptomsCount,
            createdBowelMovementsCount: createdBowelMovementsCount,
            skippedRowsCount: skippedRowsCount,
            errors: [],
            warnings: warnings
        )
    }
    
    private func clearExistingData() throws {
        let dbManager = DatabaseManager.shared
        
        try dbManager.write { db in
            // Clear all existing logs
            try db.execute(sql: "DELETE FROM dailyLog")
            
            // Clear all bowel movements  
            try db.execute(sql: "DELETE FROM bowelMovement")
            
            // Note: We don't clear symptoms or medications as they might be reused
        }
    }
    
    private func createMissingSymptoms(_ symptomColumns: [String]) throws -> Int {
        let existingSymptoms = SymptomsRepo.shared.getTrackedSymptoms()
        let existingNames = Set(existingSymptoms.map { $0.name })
        
        var createdCount = 0
        for symptomName in symptomColumns {
            if !existingNames.contains(symptomName) {
                let newSymptom = TrackedSymptom(name: symptomName)
                if SymptomsRepo.shared.saveSymptom(newSymptom) {
                    createdCount += 1
                }
            }
        }
        
        return createdCount
    }
    
    private func createDailyLogFromRow(
        row: [String],
        headers: [String],
        columnMap: [String: Int],
        symptomColumns: [String]
    ) throws -> (DailyLog, Int) {
        
        // Parse date (required)
        guard let dateIndex = columnMap["Date"],
              let date = parseDate(row[dateIndex]) else {
            throw ImportError.invalidDateFormat(row[columnMap["Date"] ?? 0])
        }
        
        // Parse optional fields
        let mood = parseOptionalInt(getValue("Mood", row: row, columnMap: columnMap))
        let painLevel = parseOptionalInt(getValue("Pain Level", row: row, columnMap: columnMap))
        let energyLevel = parseOptionalInt(getValue("Energy Level", row: row, columnMap: columnMap))
        let isFlareDay = parseFlareDay(getValue("Flare Day", row: row, columnMap: columnMap))
        let weather = getValue("Weather", row: row, columnMap: columnMap)
        
        // Parse list fields
        let medications = parseListField(getValue("Medications", row: row, columnMap: columnMap))
        let meals = parseListField(getValue("Meals", row: row, columnMap: columnMap))
        let activities = parseListField(getValue("Activities", row: row, columnMap: columnMap))
        let notes = getValue("Notes", row: row, columnMap: columnMap)
        
        // Parse symptom ratings
        let symptomRatings = try parseSymptomRatings(row: row, columnMap: columnMap, symptomColumns: symptomColumns)
        
        // Parse bowel movements and create them
        let bowelMovementsData = getValue("Bowel Movements", row: row, columnMap: columnMap)
        let bowelMovements = try parseBowelMovements(bowelMovementsData, for: date)
        
        // Save bowel movements
        var savedBowelMovementCount = 0
        for movement in bowelMovements {
            if BowelMovementRepo.shared.save([movement]) {
                savedBowelMovementCount += 1
            }
        }
        
        // Create daily log
        let dailyLog = DailyLog(
            date: date,
            mood: mood,
            painLevel: painLevel,
            energyLevel: energyLevel,
            meals: meals,
            activities: activities,
            medicationsTaken: medications,
            medicationAdherence: [], // Not exported, so empty on import
            notes: notes.isEmpty ? nil : notes,
            isFlareDay: isFlareDay,
            weather: weather.isEmpty ? nil : weather,
            symptomRatings: symptomRatings
        )
        
        return (dailyLog, savedBowelMovementCount)
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
    
    private func parseSymptomRatings(row: [String], columnMap: [String: Int], symptomColumns: [String]) throws -> [SymptomRating] {
        var ratings: [SymptomRating] = []
        
        // Get all tracked symptoms to map names to IDs
        let trackedSymptoms = SymptomsRepo.shared.getTrackedSymptoms()
        
        for symptomName in symptomColumns {
            let value = getValue(symptomName, row: row, columnMap: columnMap)
            guard !value.isEmpty, let rating = Int(value) else { continue }
            
            // Find symptom ID
            if let symptom = trackedSymptoms.first(where: { $0.name == symptomName }),
               let symptomId = symptom.id {
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
    
    @MainActor
    private func updateProgress(_ progress: Double) {
        self.importProgress = progress
    }
}
