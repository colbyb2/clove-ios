import Foundation
import GRDB

protocol AdvancedInsightRepository {
    func fetchFeedback() throws -> [InsightFeedback]
    func feedback(for insightID: String) throws -> InsightFeedback?
    @discardableResult func saveFeedback(_ feedback: InsightFeedback) throws -> InsightFeedback
    func fetchHypotheses() throws -> [SavedHypothesis]
    @discardableResult func saveHypothesis(_ hypothesis: SavedHypothesis) throws -> SavedHypothesis
    func deleteHypothesis(id: Int64) throws
    func markHypothesisReviewed(id: Int64, at date: Date) throws
}

struct AdvancedInsightRepo: AdvancedInsightRepository {
    let databaseManager: DatabaseManaging

    init(databaseManager: DatabaseManaging = DatabaseManager.shared) {
        self.databaseManager = databaseManager
    }

    func fetchFeedback() throws -> [InsightFeedback] {
        try databaseManager.read { db in
            try InsightFeedback.order(Column("updatedAt").desc).fetchAll(db)
        }
    }

    func feedback(for insightID: String) throws -> InsightFeedback? {
        try databaseManager.read { db in try InsightFeedback.fetchOne(db, key: insightID) }
    }

    @discardableResult
    func saveFeedback(_ feedback: InsightFeedback) throws -> InsightFeedback {
        try databaseManager.writeReturning { db in
            var value = feedback
            value.updatedAt = Date()
            try value.save(db)
            return value
        }
    }

    func fetchHypotheses() throws -> [SavedHypothesis] {
        try databaseManager.read { db in
            try SavedHypothesis.order(Column("updatedAt").desc, Column("id").desc).fetchAll(db)
        }
    }

    @discardableResult
    func saveHypothesis(_ hypothesis: SavedHypothesis) throws -> SavedHypothesis {
        try databaseManager.writeReturning { db in
            var value = hypothesis
            value.updatedAt = Date()
            try value.save(db)
            return value
        }
    }

    func deleteHypothesis(id: Int64) throws {
        try databaseManager.write { db in _ = try SavedHypothesis.deleteOne(db, key: id) }
    }

    func markHypothesisReviewed(id: Int64, at date: Date = Date()) throws {
        try databaseManager.write { db in
            try db.execute(sql: "UPDATE savedHypothesis SET lastReviewedAt = ?, updatedAt = ? WHERE id = ?",
                           arguments: [date, date, id])
        }
    }
}
