import Foundation
import GRDB

final class FoodEntryRepo {
    static let shared = FoodEntryRepo(databaseManager: DatabaseManager.shared)

    private let databaseManager: DatabaseManaging

    init(databaseManager: DatabaseManaging) {
        self.databaseManager = databaseManager
    }

    // MARK: - CRUD Operations

    @discardableResult
    func save(_ entry: FoodEntry) -> FoodEntry? {
        do {
            var newEntry = entry
            try databaseManager.write { db in
                try newEntry.insert(db)
            }
            return newEntry
        } catch {
            print("Error saving food entry: \(error)")
            return nil
        }
    }

    func save(_ entries: [FoodEntry]) -> Bool {
        do {
            try databaseManager.write { db -> Void in
                for var entry in entries {
                    try entry.insert(db)
                }
            }
            return true
        } catch {
            print("Error saving food entries: \(error)")
            return false
        }
    }

    func update(_ entry: FoodEntry) -> Bool {
        guard entry.id != nil else { return false }
        do {
            try databaseManager.write { db in
                try entry.update(db)
            }
            return true
        } catch {
            print("Error updating food entry: \(error)")
            return false
        }
    }

    func delete(id: Int64) -> Bool {
        do {
            try databaseManager.write { db in
                try db.execute(sql: "DELETE FROM foodEntry WHERE id = ?", arguments: [id])
            }
            return true
        } catch {
            print("Error deleting food entry: \(error)")
            return false
        }
    }

    // MARK: - Query Operations

    func getEntriesForDate(_ date: Date) -> [FoodEntry] {
        do {
            return try databaseManager.read { db in
                let calendar = Calendar.current
                let startOfDay = calendar.startOfDay(for: date)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

                return try FoodEntry
                    .filter(FoodEntry.Columns.date >= startOfDay && FoodEntry.Columns.date < endOfDay)
                    .order(FoodEntry.Columns.date.asc)
                    .fetchAll(db)
            }
        } catch {
            print("Error getting food entries for date: \(error)")
            return []
        }
    }

    func getAllEntries() -> [FoodEntry] {
        do {
            return try databaseManager.read { db in
                try FoodEntry
                    .order(FoodEntry.Columns.date.desc)
                    .fetchAll(db)
            }
        } catch {
            print("Error getting all food entries: \(error)")
            return []
        }
    }

    func getEntries(for period: TimePeriod) -> [FoodEntry] {
        do {
            return try databaseManager.read { db in
                if period == .allTime {
                    return try FoodEntry
                        .order(FoodEntry.Columns.date.desc)
                        .fetchAll(db)
                } else {
                    let calendar = Calendar.current
                    let endDate = calendar.startOfDay(for: Date())
                    let startDate = calendar.date(byAdding: .day, value: -period.days + 1, to: endDate)!
                    let endOfDay = calendar.date(byAdding: .day, value: 1, to: endDate)!

                    return try FoodEntry
                        .filter(FoodEntry.Columns.date >= startDate && FoodEntry.Columns.date < endOfDay)
                        .order(FoodEntry.Columns.date.desc)
                        .fetchAll(db)
                }
            }
        } catch {
            print("Error getting food entries for period: \(error)")
            return []
        }
    }

    func getFavorites() -> [FoodEntry] {
        do {
            return try databaseManager.read { db in
                try FoodEntry
                    .filter(FoodEntry.Columns.isFavorite == true)
                    .order(FoodEntry.Columns.name.asc)
                    .fetchAll(db)
            }
        } catch {
            print("Error getting favorite food entries: \(error)")
            return []
        }
    }

    func getRecentFoodNames(limit: Int) -> [String] {
        do {
            return try databaseManager.read { db in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT DISTINCT name FROM foodEntry
                    ORDER BY date DESC
                    LIMIT ?
                """, arguments: [limit])
                return rows.map { $0["name"] as String }
            }
        } catch {
            print("Error getting recent food names: \(error)")
            return []
        }
    }

    func getEntriesGroupedByCategory(for date: Date) -> [MealCategory: [FoodEntry]] {
        let entries = getEntriesForDate(date)
        return Dictionary(grouping: entries, by: { $0.category })
    }

    func toggleFavorite(id: Int64) -> Bool {
        do {
            try databaseManager.write { db in
                try db.execute(sql: """
                    UPDATE foodEntry SET isFavorite = NOT isFavorite WHERE id = ?
                """, arguments: [id])
            }
            return true
        } catch {
            print("Error toggling favorite: \(error)")
            return false
        }
    }

    func search(query: String) -> [FoodEntry] {
        guard !query.isEmpty else { return [] }
        do {
            return try databaseManager.read { db in
                try FoodEntry
                    .filter(FoodEntry.Columns.name.like("%\(query)%"))
                    .order(FoodEntry.Columns.date.desc)
                    .fetchAll(db)
            }
        } catch {
            print("Error searching food entries: \(error)")
            return []
        }
    }
}

// MARK: - Protocol Conformance
extension FoodEntryRepo: FoodEntryRepositoryProtocol {}
