import Foundation
import GRDB

protocol SavedAnalysisRepository {
    func fetchAll() throws -> [SavedAnalysis]
    @discardableResult func save(_ analysis: SavedAnalysis) throws -> SavedAnalysis
    func rename(id: Int64, title: String) throws
    func delete(id: Int64) throws
}

struct SavedAnalysisRepo: SavedAnalysisRepository {
    let databaseManager: DatabaseManaging

    init(databaseManager: DatabaseManaging = DatabaseManager.shared) {
        self.databaseManager = databaseManager
    }

    func fetchAll() throws -> [SavedAnalysis] {
        try databaseManager.read { db in
            try SavedAnalysis.order(Column("displayOrder").asc, Column("id").asc).fetchAll(db)
        }
    }

    @discardableResult
    func save(_ analysis: SavedAnalysis) throws -> SavedAnalysis {
        try databaseManager.writeReturning { db in
            var value = analysis
            value.updatedAt = Date()
            try value.save(db)
            return value
        }
    }

    func rename(id: Int64, title: String) throws {
        try databaseManager.write { db in
            try db.execute(sql: "UPDATE savedAnalysis SET title = ?, updatedAt = ? WHERE id = ?", arguments: [title, Date(), id])
        }
    }

    func delete(id: Int64) throws {
        try databaseManager.write { db in
            _ = try SavedAnalysis.deleteOne(db, key: id)
        }
    }
}
