import Foundation
import GRDB

class LogsRepo {
   static let shared = LogsRepo(databaseManager: DatabaseManager.shared)

   private let databaseManager: DatabaseManaging
   private let analyticsRevisionSource: any AnalyticsRevisionProviding

   init(
      databaseManager: DatabaseManaging,
      analyticsRevisionSource: any AnalyticsRevisionProviding = AnalyticsRevisionSource.shared
   ) {
      self.databaseManager = databaseManager
      self.analyticsRevisionSource = analyticsRevisionSource
   }
   
   func saveLog(_ log: DailyLog) -> Bool {
      do {
         try databaseManager.write { db in
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
         analyticsRevisionSource.bump(reason: .dailyLog)
         return true
      } catch {
         print("Error saving log: \(error)")
         return false
      }
   }

   func saveWaterIntake(_ ounces: Int?, for date: Date) -> Bool {
      do {
         try databaseManager.write { db in
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            if let existingLog = try DailyLog
               .filter(Column("date") >= startOfDay && Column("date") < endOfDay)
               .fetchOne(db) {
               try db.execute(
                  sql: "UPDATE dailyLog SET waterIntake = ? WHERE id = ?",
                  arguments: [ounces, existingLog.id]
               )
            } else if let ounces {
               let log = DailyLog(date: date, waterIntake: ounces)
               try log.insert(db)
            }
         }
         analyticsRevisionSource.bump(reason: .dailyLog)
         return true
      } catch {
         print("Error saving water intake: \(error)")
         return false
      }
   }
   
   func getLogs() -> [DailyLog] {
      do {
         return try databaseManager.read { db in
            try DailyLog.fetchAll(db)
         }
      } catch {
         print("Error getting logs: \(error)")
         return []
      }
   }
   
   func getLogForDate(_ date: Date) -> DailyLog? {
      do {
         return try databaseManager.read { db in
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            return try DailyLog.filter(Column("date") >= startOfDay && Column("date") < endOfDay).fetchOne(db)
         }
      } catch {
         print("Error getting log for date: \(error)")
         return nil
      }
   }

   func getLogsInRange(from startDate: Date, to endDate: Date) -> [DailyLog] {
      do {
         return try databaseManager.read { db in
            try DailyLog.filter(Column("date") >= startDate && Column("date") <= endDate).fetchAll(db)
         }
      } catch {
         print("Error getting logs in range: \(error)")
         return []
      }
   }
}

// MARK: - Protocol Conformance
extension LogsRepo: LogsRepositoryProtocol {}
