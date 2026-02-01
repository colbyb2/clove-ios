import Foundation
import GRDB

final class ActivityEntryRepo {
    static let shared = ActivityEntryRepo(databaseManager: DatabaseManager.shared)

    private let databaseManager: DatabaseManaging

    init(databaseManager: DatabaseManaging) {
        self.databaseManager = databaseManager
    }

    // MARK: - CRUD Operations

    @discardableResult
    func save(_ entry: ActivityEntry) -> ActivityEntry? {
        do {
            let newEntry = entry
            try databaseManager.write { db in
                try newEntry.insert(db)
            }
            return newEntry
        } catch {
            print("Error saving activity entry: \(error)")
            return nil
        }
    }

    func save(_ entries: [ActivityEntry]) -> Bool {
        do {
            try databaseManager.write { db -> Void in
                for entry in entries {
                    try entry.insert(db)
                }
            }
            return true
        } catch {
            print("Error saving activity entries: \(error)")
            return false
        }
    }

    func update(_ entry: ActivityEntry) -> Bool {
        guard entry.id != nil else { return false }
        do {
            try databaseManager.write { db in
                try entry.update(db)
            }
            return true
        } catch {
            print("Error updating activity entry: \(error)")
            return false
        }
    }

    func delete(id: Int64) -> Bool {
        do {
            try databaseManager.write { db in
                try db.execute(sql: "DELETE FROM activityEntry WHERE id = ?", arguments: [id])
            }
            return true
        } catch {
            print("Error deleting activity entry: \(error)")
            return false
        }
    }

    // MARK: - Query Operations

    func getEntriesForDate(_ date: Date) -> [ActivityEntry] {
        do {
            return try databaseManager.read { db in
                let calendar = Calendar.current
                let startOfDay = calendar.startOfDay(for: date)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

                return try ActivityEntry
                    .filter(ActivityEntry.Columns.date >= startOfDay && ActivityEntry.Columns.date < endOfDay)
                    .order(ActivityEntry.Columns.date.asc)
                    .fetchAll(db)
            }
        } catch {
            print("Error getting activity entries for date: \(error)")
            return []
        }
    }

    func getAllEntries() -> [ActivityEntry] {
        do {
            return try databaseManager.read { db in
                try ActivityEntry
                    .order(ActivityEntry.Columns.date.desc)
                    .fetchAll(db)
            }
        } catch {
            print("Error getting all activity entries: \(error)")
            return []
        }
    }

    func getEntries(for period: TimePeriod) -> [ActivityEntry] {
        do {
            return try databaseManager.read { db in
                if period == .allTime {
                    return try ActivityEntry
                        .order(ActivityEntry.Columns.date.desc)
                        .fetchAll(db)
                } else {
                    let calendar = Calendar.current
                    let endDate = calendar.startOfDay(for: Date())
                    let startDate = calendar.date(byAdding: .day, value: -period.days + 1, to: endDate)!
                    let endOfDay = calendar.date(byAdding: .day, value: 1, to: endDate)!

                    return try ActivityEntry
                        .filter(ActivityEntry.Columns.date >= startDate && ActivityEntry.Columns.date < endOfDay)
                        .order(ActivityEntry.Columns.date.desc)
                        .fetchAll(db)
                }
            }
        } catch {
            print("Error getting activity entries for period: \(error)")
            return []
        }
    }

    func getFavorites() -> [ActivityEntry] {
        do {
            return try databaseManager.read { db in
                try ActivityEntry
                    .filter(ActivityEntry.Columns.isFavorite == true)
                    .order(ActivityEntry.Columns.name.asc)
                    .fetchAll(db)
            }
        } catch {
            print("Error getting favorite activity entries: \(error)")
            return []
        }
    }

    func getRecentActivityNames(limit: Int) -> [String] {
        do {
            return try databaseManager.read { db in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT DISTINCT name FROM activityEntry
                    ORDER BY date DESC
                    LIMIT ?
                """, arguments: [limit])
                return rows.map { $0["name"] as String }
            }
        } catch {
            print("Error getting recent activity names: \(error)")
            return []
        }
    }

    func getEntriesGroupedByCategory(for date: Date) -> [ActivityCategory: [ActivityEntry]] {
        let entries = getEntriesForDate(date)
        return Dictionary(grouping: entries, by: { $0.category })
    }

    func toggleFavorite(id: Int64) -> Bool {
        do {
            try databaseManager.write { db in
                try db.execute(sql: """
                    UPDATE activityEntry SET isFavorite = NOT isFavorite WHERE id = ?
                """, arguments: [id])
            }
            return true
        } catch {
            print("Error toggling favorite: \(error)")
            return false
        }
    }

    func search(query: String) -> [ActivityEntry] {
        guard !query.isEmpty else { return [] }
        do {
            return try databaseManager.read { db in
                try ActivityEntry
                    .filter(ActivityEntry.Columns.name.like("%\(query)%"))
                    .order(ActivityEntry.Columns.date.desc)
                    .fetchAll(db)
            }
        } catch {
            print("Error searching activity entries: \(error)")
            return []
        }
    }

    func getTotalDuration(for date: Date) -> Int {
        let entries = getEntriesForDate(date)
        return entries.compactMap { $0.duration }.reduce(0, +)
    }
}

// MARK: - Protocol Conformance
extension ActivityEntryRepo: ActivityEntryRepositoryProtocol {}
