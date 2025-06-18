import Foundation
import GRDB

class LogsRepo {
    static let shared = LogsRepo()

    private let dbManager = DatabaseManager.shared

    func saveLog(_ log: DailyLog) -> Bool {
        do {
            try dbManager.write { db in
                // Check if a log already exists for this date
                let calendar = Calendar.current
                let startOfDay = calendar.startOfDay(for: log.date)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                
                // Try to find an existing log for today
                if let existingLog = try DailyLog.filter(Column("date") >= startOfDay && Column("date") < endOfDay).fetchOne(db) {
                    // Update the existing log with the new log's ID
                    var updatedLog = log
                    updatedLog.id = existingLog.id
                    try updatedLog.update(db)
                } else {
                    // No existing log, save as new
                    try log.save(db)
                }
            }
            return true
        } catch {
            print("Error saving log: \(error)")
            return false
        }
    }
}