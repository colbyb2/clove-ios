import Foundation
import GRDB

class LogsRepo {
   static let shared = LogsRepo(databaseManager: DatabaseManager.shared)

   private let databaseManager: DatabaseManaging
   private let analyticsRevisionSource: any AnalyticsRevisionProviding
   private let calendar: Calendar

   init(
      databaseManager: DatabaseManaging,
      analyticsRevisionSource: any AnalyticsRevisionProviding = AnalyticsRevisionSource.shared,
      calendar: Calendar = .current
   ) {
      self.databaseManager = databaseManager
      self.analyticsRevisionSource = analyticsRevisionSource
      self.calendar = calendar
   }
   
   func saveLog(_ log: DailyLog) -> Bool {
      do {
         try databaseManager.write { db in
            var normalizedLog = log
            normalizedLog.dayKey = LocalDayKey.make(for: log.date, calendar: calendar)
            try normalizedLog.upsert(db)
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
            let dayKey = LocalDayKey.make(for: date, calendar: calendar)

            if let existingLog = try DailyLog
               .filter(Column("dayKey") == dayKey)
               .fetchOne(db) {
               try db.execute(
                  sql: "UPDATE dailyLog SET waterIntake = ? WHERE id = ?",
                  arguments: [ounces, existingLog.id]
               )
            } else if let ounces {
               let log = DailyLog(date: date, dayKey: dayKey, waterIntake: ounces)
               try log.upsert(db)
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
            try DailyLog.order(Column("dayKey").asc).fetchAll(db)
         }
      } catch {
         print("Error getting logs: \(error)")
         return []
      }
   }
   
   func getLogForDate(_ date: Date) -> DailyLog? {
      do {
         return try databaseManager.read { db in
            let dayKey = LocalDayKey.make(for: date, calendar: calendar)
            return try DailyLog.filter(Column("dayKey") == dayKey).fetchOne(db)
         }
      } catch {
         print("Error getting log for date: \(error)")
         return nil
      }
   }

   func getLogsInRange(from startDate: Date, to endDate: Date) -> [DailyLog] {
      do {
         return try databaseManager.read { db in
            let startKey = LocalDayKey.make(for: startDate, calendar: calendar)
            let endKey = LocalDayKey.make(for: endDate, calendar: calendar)
            return try DailyLog
               .filter(Column("dayKey") >= startKey && Column("dayKey") <= endKey)
               .order(Column("dayKey").asc)
               .fetchAll(db)
         }
      } catch {
         print("Error getting logs in range: \(error)")
         return []
      }
   }
}

// MARK: - Protocol Conformance
extension LogsRepo: LogsRepositoryProtocol {}
