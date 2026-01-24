import Foundation
import GRDB

final class BowelMovementRepo {
    static let shared = BowelMovementRepo(databaseManager: DatabaseManager.shared)

    private let databaseManager: DatabaseManaging

    init(databaseManager: DatabaseManaging) {
        self.databaseManager = databaseManager
    }
    
    // MARK: - CRUD Operations
    
    func save(_ bowelMovements: [BowelMovement]) -> Bool {
        do {
            try databaseManager.write { db in
                for movement in bowelMovements {
                    try movement.save(db)
                }
            }
            return true
        } catch {
            print("Error saving bowel movements: \(error)")
            return false
        }
    }
    
    func delete(id: Int64) -> Bool {
        do {
            try databaseManager.write { db in
                try db.execute(sql: "DELETE FROM bowelMovement WHERE id = ?", arguments: [id])
            }
            return true
        } catch {
            print("Error deleting bowel movement: \(error)")
            return false
        }
    }
    
    func getBowelMovementsForDate(_ date: Date) -> [BowelMovement] {
        do {
            return try databaseManager.read { db in
                let calendar = Calendar.current
                let startOfDay = calendar.startOfDay(for: date)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                
                return try BowelMovement.fetchAll(db, sql: "SELECT * FROM bowelMovement WHERE date >= ? AND date < ? ORDER BY date DESC", arguments: [startOfDay, endOfDay])
            }
        } catch {
            print("Error getting bowel movements for date: \(error)")
            return []
        }
    }
    
    func getAllBowelMovements() -> [BowelMovement] {
        do {
            return try databaseManager.read { db in
                try BowelMovement.fetchAll(db, sql: "SELECT * FROM bowelMovement ORDER BY date DESC")
            }
        } catch {
            print("Error getting all bowel movements: \(error)")
            return []
        }
    }
    
    func getBowelMovements(for period: TimePeriod) -> [BowelMovement] {
        do {
            return try databaseManager.read { db in
                if period == .allTime {
                    return try BowelMovement.fetchAll(db, sql: "SELECT * FROM bowelMovement ORDER BY date DESC")
                } else {
                    let calendar = Calendar.current
                    let endDate = calendar.startOfDay(for: Date())
                    let startDate = calendar.date(byAdding: .day, value: -period.days + 1, to: endDate)!
                    let endOfDay = calendar.date(byAdding: .day, value: 1, to: endDate)!
                    
                    return try BowelMovement.fetchAll(db, sql: "SELECT * FROM bowelMovement WHERE date >= ? AND date < ? ORDER BY date DESC", arguments: [startDate, endOfDay])
                }
            }
        } catch {
            print("Error getting bowel movements for period: \(error)")
            return []
        }
    }
}

// MARK: - Protocol Conformance
extension BowelMovementRepo: BowelMovementRepositoryProtocol {}
