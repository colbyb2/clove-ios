import Foundation
import GRDB

enum PacingPlanState: String, Codable, CaseIterable {
    case planned
    case completed
    case deferred
    case removed

    var title: String {
        switch self {
        case .planned: "Planned"
        case .completed: "Done"
        case .deferred: "Later"
        case .removed: "Removed"
        }
    }
}

/// A gentle intention for a day. Plans intentionally live outside activity data so
/// completing one never changes activity totals, streaks, or analytics.
struct PacingPlanItem: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var title: String
    var date: Date
    var state: PacingPlanState
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    static let databaseTableName = "pacingPlanItem"

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let title = Column(CodingKeys.title)
        static let date = Column(CodingKeys.date)
        static let state = Column(CodingKeys.state)
        static let sortOrder = Column(CodingKeys.sortOrder)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }
}
