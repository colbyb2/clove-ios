import Foundation
import GRDB

enum InsightFeedbackRating: String, Codable, CaseIterable, Sendable {
    case useful
    case notUseful
}

struct InsightFeedback: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "insightFeedback"

    var id: String { insightID }
    var insightID: String
    var rating: String?
    var isSaved: Bool
    var dismissedUntil: Date?
    var createdAt: Date
    var updatedAt: Date

    var feedbackRating: InsightFeedbackRating? {
        get { rating.flatMap(InsightFeedbackRating.init(rawValue:)) }
        set { rating = newValue?.rawValue }
    }

    func isDismissed(at date: Date = Date()) -> Bool {
        guard let dismissedUntil else { return false }
        return dismissedUntil > date
    }

    init(insightID: String, rating: InsightFeedbackRating? = nil, isSaved: Bool = false,
         dismissedUntil: Date? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.insightID = insightID
        self.rating = rating?.rawValue
        self.isSaved = isSaved
        self.dismissedUntil = dismissedUntil
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct SavedHypothesis: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "savedHypothesis"

    var id: Int64?
    var title: String
    var factorMetricID: String
    var outcomeMetricID: String
    var notes: String
    var reviewIntervalDays: Int
    var lastReviewedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(id: Int64? = nil, title: String, factorMetricID: String, outcomeMetricID: String,
         notes: String = "", reviewIntervalDays: Int = 7, lastReviewedAt: Date? = nil,
         createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.factorMetricID = factorMetricID
        self.outcomeMetricID = outcomeMetricID
        self.notes = notes
        self.reviewIntervalDays = max(1, reviewIntervalDays)
        self.lastReviewedAt = lastReviewedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
