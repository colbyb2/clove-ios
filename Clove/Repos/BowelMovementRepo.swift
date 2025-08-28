import Foundation
import GRDB

class BowelMovementRepo {
    static let shared = BowelMovementRepo()
    
    private let dbManager = DatabaseManager.shared
    
    private init() {}
    
    // MARK: - CRUD Operations
    
    func save(_ bowelMovements: [BowelMovement]) -> Bool {
        do {
            try dbManager.write { db in
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
            try dbManager.write { db in
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
            return try dbManager.read { db in
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
            return try dbManager.read { db in
                try BowelMovement.fetchAll(db, sql: "SELECT * FROM bowelMovement ORDER BY date DESC")
            }
        } catch {
            print("Error getting all bowel movements: \(error)")
            return []
        }
    }
}