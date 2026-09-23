import Foundation
import GRDB

final class ActivityCategoryRepo {
    static let shared = ActivityCategoryRepo(databaseManager: DatabaseManager.shared)

    private let databaseManager: DatabaseManaging

    init(databaseManager: DatabaseManaging) {
        self.databaseManager = databaseManager
    }

    func getAll() -> [ActivityCategoryDefinition] {
        (try? databaseManager.read { db in
            try ActivityCategoryDefinition.order(Column("sortOrder").asc).fetchAll(db)
        }) ?? ActivityCategoryDefinition.presets
    }

    func definition(for id: String?) -> ActivityCategoryDefinition {
        guard let id else { return ActivityCategoryDefinition.fallback }
        return (try? databaseManager.read { db in
            try ActivityCategoryDefinition.fetchOne(db, key: id)
        }) ?? ActivityCategoryDefinition.presets.first(where: { $0.id == id }) ?? .fallback
    }

    @discardableResult
    func save(_ definition: ActivityCategoryDefinition) -> Bool {
        do {
            try databaseManager.write { db in try definition.save(db) }
            return true
        } catch {
            print("Error saving activity category: \(error)")
            return false
        }
    }

    @discardableResult
    func create(name: String, symbol: String, colorHex: String) -> ActivityCategoryDefinition? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let nextOrder = (getAll().map(\.sortOrder).max() ?? -1) + 1
        let definition = ActivityCategoryDefinition(
            id: UUID().uuidString.lowercased(),
            name: trimmed,
            symbol: symbol,
            colorHex: colorHex,
            isPreset: false,
            sortOrder: nextOrder
        )
        return save(definition) ? definition : nil
    }

    @discardableResult
    func delete(_ definition: ActivityCategoryDefinition) -> Bool {
        guard !definition.isPreset else { return false }
        do {
            try databaseManager.write { db in
                try db.execute(
                    sql: "UPDATE activityEntry SET categoryID = 'other', category = 'other' WHERE categoryID = ?",
                    arguments: [definition.id]
                )
                try ActivityCategoryDefinition.deleteOne(db, key: definition.id)
            }
            return true
        } catch {
            print("Error deleting activity category: \(error)")
            return false
        }
    }
}
