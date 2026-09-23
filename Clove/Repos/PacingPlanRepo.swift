import Foundation
import GRDB

final class PacingPlanRepo {
    static let shared = PacingPlanRepo(databaseManager: DatabaseManager.shared)

    private let databaseManager: DatabaseManaging
    private let calendar: Calendar

    init(databaseManager: DatabaseManaging, calendar: Calendar = .current) {
        self.databaseManager = databaseManager
        self.calendar = calendar
    }

    func visibleItems(for date: Date) -> [PacingPlanItem] {
        do {
            return try databaseManager.read { db in
                let start = calendar.startOfDay(for: date)
                let end = calendar.date(byAdding: .day, value: 1, to: start)!
                return try PacingPlanItem
                    .filter(PacingPlanItem.Columns.date >= start && PacingPlanItem.Columns.date < end)
                    .filter(PacingPlanItem.Columns.state != PacingPlanState.removed.rawValue)
                    .order(PacingPlanItem.Columns.sortOrder.asc, PacingPlanItem.Columns.createdAt.asc)
                    .fetchAll(db)
            }
        } catch {
            print("Error loading pacing plans: \(error)")
            return []
        }
    }

    func unfinishedCount(for date: Date) -> Int {
        visibleItems(for: date).filter { $0.state == .planned || $0.state == .deferred }.count
    }

    @discardableResult
    func add(title: String, for date: Date) -> Bool {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return false }

        do {
            try databaseManager.write { db in
                let start = calendar.startOfDay(for: date)
                let end = calendar.date(byAdding: .day, value: 1, to: start)!
                let nextOrder = (try Int.fetchOne(
                    db,
                    sql: "SELECT MAX(sortOrder) FROM pacingPlanItem WHERE date >= ? AND date < ?",
                    arguments: [start, end]
                ) ?? -1) + 1
                let now = Date()
                let item = PacingPlanItem(
                    title: cleanTitle,
                    date: start,
                    state: .planned,
                    sortOrder: nextOrder,
                    createdAt: now,
                    updatedAt: now
                )
                try item.insert(db)
            }
            return true
        } catch {
            print("Error adding pacing plan: \(error)")
            return false
        }
    }

    @discardableResult
    func setState(_ state: PacingPlanState, for item: PacingPlanItem) -> Bool {
        guard item.id != nil else { return false }
        do {
            var updated = item
            updated.state = state
            updated.updatedAt = Date()
            try databaseManager.write { db in try updated.update(db) }
            return true
        } catch {
            print("Error updating pacing plan: \(error)")
            return false
        }
    }
}
