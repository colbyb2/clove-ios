import Foundation
import GRDB

struct SavedAnalysis: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "savedAnalysis"

    var id: Int64?
    var title: String
    var factorMetricID: String
    var outcomeMetricID: String
    var rangePolicy: String
    var method: String?
    var lagDays: Int
    var filtersJSON: String
    var displayOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(id: Int64? = nil, title: String, factorMetricID: String, outcomeMetricID: String,
         rangePolicy: String, method: String? = nil, lagDays: Int = 0, filtersJSON: String = "{}",
         displayOrder: Int = 0, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.factorMetricID = factorMetricID
        self.outcomeMetricID = outcomeMetricID
        self.rangePolicy = rangePolicy
        self.method = method
        self.lagDays = lagDays
        self.filtersJSON = filtersJSON
        self.displayOrder = displayOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
