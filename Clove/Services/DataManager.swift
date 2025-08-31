import SwiftUI
import Foundation

@Observable
class DataManager {
    static let shared = DataManager()
    
    private init() {}
    
    // MARK: - Export Status
    var isExporting: Bool = false
    var exportProgress: Double = 0.0
    var exportError: String? = nil
    
    // MARK: - CSV Export Function
    func exportToCSV(
        categories: Set<ExportCategory>,
        symptomIds: Set<Int64>,
        completion: @escaping (Result<URL, DataExportError>) -> Void
    ) {
        // Reset state
        isExporting = true
        exportProgress = 0.0
        exportError = nil
        
        Task {
            do {
                let csvURL = try await generateCSVFile(categories: categories, symptomIds: symptomIds)
                
                await MainActor.run {
                    self.isExporting = false
                    self.exportProgress = 1.0
                    completion(.success(csvURL))
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    self.exportError = error.localizedDescription
                    
                    if let exportError = error as? DataExportError {
                        completion(.failure(exportError))
                    } else {
                        completion(.failure(.unknown(error.localizedDescription)))
                    }
                }
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func generateCSVFile(categories: Set<ExportCategory>, symptomIds: Set<Int64>) async throws -> URL {
        // Update progress
        await updateProgress(0.1)
        
        // Fetch all logs from database
        let logs = LogsRepo.shared.getLogs()
        guard !logs.isEmpty else {
            throw DataExportError.noData
        }
        
        await updateProgress(0.3)
        
        // Get symptom information for selected symptoms
        let selectedSymptoms = SymptomsRepo.shared.getTrackedSymptoms().filter { symptom in
            guard let id = symptom.id else { return false }
            return symptomIds.contains(id)
        }
        
        await updateProgress(0.4)
        
        // Generate CSV content
        let csvContent = try generateCSVContent(
            logs: logs,
            categories: categories,
            selectedSymptoms: selectedSymptoms
        )
        
        await updateProgress(0.8)
        
        // Write to temporary file
        let csvURL = try writeCSVToFile(content: csvContent)
        
        await updateProgress(1.0)
        
        return csvURL
    }
    
    private func generateCSVContent(
        logs: [DailyLog],
        categories: Set<ExportCategory>,
        selectedSymptoms: [TrackedSymptom]
    ) throws -> String {
        var csvLines: [String] = []
        
        // Generate header row
        let headers = generateCSVHeaders(categories: categories, selectedSymptoms: selectedSymptoms)
        csvLines.append(headers.joined(separator: ","))
        
        // Sort logs by date (oldest first)
        let sortedLogs = logs.sorted { $0.date < $1.date }
        
        // Generate data rows
        for log in sortedLogs {
            let row = generateCSVRow(log: log, categories: categories, selectedSymptoms: selectedSymptoms)
            csvLines.append(row.joined(separator: ","))
        }
        
        return csvLines.joined(separator: "\n")
    }
    
    private func generateCSVHeaders(categories: Set<ExportCategory>, selectedSymptoms: [TrackedSymptom]) -> [String] {
        var headers: [String] = []
        
        // Add category headers in logical order
        let orderedCategories: [ExportCategory] = [.date, .mood, .pain, .energy, .flareDay, .weather, .bowelMovements, .medications, .meals, .activities, .notes]
        
        for category in orderedCategories {
            if categories.contains(category) {
                headers.append(escapeCSVField(category.rawValue))
            }
        }
        
        // Add symptom headers
        for symptom in selectedSymptoms.sorted(by: { $0.name < $1.name }) {
            headers.append(escapeCSVField(symptom.name))
        }
        
        return headers
    }
    
    private func generateCSVRow(log: DailyLog, categories: Set<ExportCategory>, selectedSymptoms: [TrackedSymptom]) -> [String] {
        var row: [String] = []
        
        // Add category data in same order as headers
        let orderedCategories: [ExportCategory] = [.date, .mood, .pain, .energy, .flareDay, .weather, .bowelMovements, .medications, .meals, .activities, .notes]
        
        for category in orderedCategories {
            if categories.contains(category) {
                let value = getValueForCategory(category: category, log: log)
                row.append(escapeCSVField(value))
            }
        }
        
        // Add symptom data
        for symptom in selectedSymptoms.sorted(by: { $0.name < $1.name }) {
            let rating = log.symptomRatings.first { $0.symptomId == symptom.id }?.rating
            let value = rating.map { String($0) } ?? ""
            row.append(escapeCSVField(value))
        }
        
        return row
    }
    
    private func getValueForCategory(category: ExportCategory, log: DailyLog) -> String {
        switch category {
        case .date:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: log.date)
        case .mood:
            return log.mood.map { String($0) } ?? ""
        case .pain:
            return log.painLevel.map { String($0) } ?? ""
        case .energy:
            return log.energyLevel.map { String($0) } ?? ""
        case .flareDay:
            return log.isFlareDay ? "Yes" : "No"
        case .weather:
            return log.weather ?? ""
        case .bowelMovements:
            let bowelMovements = BowelMovementRepo.shared.getBowelMovementsForDate(log.date)
            if bowelMovements.isEmpty {
                return ""
            } else {
                let movements = bowelMovements.map { movement in
                    let timeFormatter = DateFormatter()
                    timeFormatter.timeStyle = .short
                    let time = timeFormatter.string(from: movement.date)
                    return "Type \(Int(movement.type)) (\(time))"
                }
                return movements.joined(separator: "; ")
            }
        case .medications:
            let takenMedications = log.medicationAdherence.filter { $0.wasTaken }.map { $0.medicationName }
            return takenMedications.joined(separator: "; ")
        case .meals:
            return log.meals.joined(separator: "; ")
        case .activities:
            return log.activities.joined(separator: "; ")
        case .notes:
            return log.notes ?? ""
        }
    }
    
    private func escapeCSVField(_ field: String) -> String {
        // If field contains comma, newline, or quotes, wrap in quotes and escape internal quotes
        if field.contains(",") || field.contains("\n") || field.contains("\"") {
            let escapedField = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escapedField)\""
        }
        return field
    }
    
    private func writeCSVToFile(content: String) throws -> URL {
        let fileName = "clove_health_data_\(formattedDateForFileName()).csv"
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        
        return fileURL
    }
    
    private func formattedDateForFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }
    
    @MainActor
    private func updateProgress(_ progress: Double) {
        self.exportProgress = progress
    }
}

// MARK: - Data Export Error Enum
enum DataExportError: LocalizedError {
    case noData
    case fileWriteError
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .noData:
            return "No health data found to export"
        case .fileWriteError:
            return "Failed to create export file"
        case .unknown(let message):
            return "Export failed: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noData:
            return "Try logging some health data first, then attempt to export again."
        case .fileWriteError:
            return "Check available storage space and try again."
        case .unknown:
            return "Please try again or contact support if the problem persists."
        }
    }
}