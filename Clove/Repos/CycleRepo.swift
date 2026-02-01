import Foundation
import GRDB

final class CycleRepo {
    static let shared = CycleRepo(databaseManager: DatabaseManager.shared)

    private let databaseManager: DatabaseManaging

    init(databaseManager: DatabaseManaging) {
        self.databaseManager = databaseManager
    }

    // MARK: - CRUD Operations

    func save(_ cycles: [Cycle]) -> Bool {
        do {
            try databaseManager.write { db in
                for cycle in cycles {
                    try cycle.save(db)
                }
            }
            return true
        } catch {
            print("Error saving cycle entries: \(error)")
            return false
        }
    }

    func delete(id: Int64) -> Bool {
        do {
            try databaseManager.write { db in
                try db.execute(sql: "DELETE FROM cycle WHERE id = ?", arguments: [id])
            }
            return true
        } catch {
            print("Error deleting cycle entry: \(error)")
            return false
        }
    }

    func getCyclesForDate(_ date: Date) -> [Cycle] {
        do {
            return try databaseManager.read { db in
                let calendar = Calendar.current
                let startOfDay = calendar.startOfDay(for: date)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

                return try Cycle.fetchAll(db, sql: "SELECT * FROM cycle WHERE date >= ? AND date < ? ORDER BY date DESC", arguments: [startOfDay, endOfDay])
            }
        } catch {
            print("Error getting cycle entries for date: \(error)")
            return []
        }
    }

    func getAllCycles() -> [Cycle] {
        do {
            return try databaseManager.read { db in
                try Cycle.fetchAll(db, sql: "SELECT * FROM cycle ORDER BY date DESC")
            }
        } catch {
            print("Error getting all cycle entries: \(error)")
            return []
        }
    }

    func getCycles(for period: TimePeriod) -> [Cycle] {
        do {
            return try databaseManager.read { db in
                if period == .allTime {
                    return try Cycle.fetchAll(db, sql: "SELECT * FROM cycle ORDER BY date DESC")
                } else {
                    let calendar = Calendar.current
                    let endDate = calendar.startOfDay(for: Date())
                    let startDate = calendar.date(byAdding: .day, value: -period.days + 1, to: endDate)!
                    let endOfDay = calendar.date(byAdding: .day, value: 1, to: endDate)!

                    return try Cycle.fetchAll(db, sql: "SELECT * FROM cycle WHERE date >= ? AND date < ? ORDER BY date DESC", arguments: [startDate, endOfDay])
                }
            }
        } catch {
            print("Error getting cycle entries for period: \(error)")
            return []
        }
    }
}

// MARK: - Protocol Conformance
extension CycleRepo: CycleRepositoryProtocol {}
