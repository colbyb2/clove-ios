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
         try persistLog(log)
         return true
      } catch {
         print("Error saving log: \(error)")
         return false
      }
   }

   func saveWaterIntake(_ ounces: Int?, for date: Date) -> Bool {
      do {
         try persistWaterIntake(ounces, for: date)
         return true
      } catch {
         print("Error saving water intake: \(error)")
         return false
      }
   }

   func getLogs() -> [DailyLog] {
      do {
         return try loadLogs()
      } catch {
         print("Error getting logs: \(error)")
         return []
      }
   }

   func getLogForDate(_ date: Date) -> DailyLog? {
      do {
         return try loadLog(for: date)
      } catch {
         print("Error getting log for date: \(error)")
         return nil
      }
   }

   func getLogsInRange(from startDate: Date, to endDate: Date) -> [DailyLog] {
      do {
         return try loadLogsInRange(from: startDate, to: endDate)
      } catch {
         print("Error getting logs in range: \(error)")
         return []
      }
   }

   func persistLog(_ log: DailyLog) throws {
      do {
         try databaseManager.write { db in
            var normalizedLog = log
            normalizedLog.dayKey = LocalDayKey.make(for: log.date, calendar: calendar)
            try normalizedLog.upsert(db)
         }
         analyticsRevisionSource.bump(reason: .dailyLog)
      } catch {
         throw RepositoryError(operation: .write, resource: "daily log", underlyingError: error)
      }
   }

   func persistWaterIntake(_ ounces: Int?, for date: Date) throws {
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
      } catch {
         throw RepositoryError(operation: .write, resource: "hydration", underlyingError: error)
      }
   }

   func loadLogs() throws -> [DailyLog] {
      do {
         return try databaseManager.read { db in
            try DailyLog.order(Column("dayKey").asc).fetchAll(db)
         }
      } catch {
         throw RepositoryError(operation: .read, resource: "daily logs", underlyingError: error)
      }
   }

   func loadLog(for date: Date) throws -> DailyLog? {
      do {
         return try databaseManager.read { db in
            let dayKey = LocalDayKey.make(for: date, calendar: calendar)
            return try DailyLog.filter(Column("dayKey") == dayKey).fetchOne(db)
         }
      } catch {
         throw RepositoryError(operation: .read, resource: "daily log", underlyingError: error)
      }
   }

   func loadLogsInRange(from startDate: Date, to endDate: Date) throws -> [DailyLog] {
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
         throw RepositoryError(operation: .read, resource: "daily logs", underlyingError: error)
      }
   }
}

// MARK: - Protocol Conformance
extension LogsRepo: LogsRepositoryProtocol {}
