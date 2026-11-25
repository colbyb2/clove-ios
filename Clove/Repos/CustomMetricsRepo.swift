import Foundation
import GRDB

protocol CustomMetricsRepositoryProtocol {
    func definitions() throws -> [CustomMetricDefinition]
    func values(on date: Date) throws -> [CustomDailyValue]
    func allValues() throws -> [CustomDailyValue]
    func hasHistory(_ id: String) throws -> Bool
    func saveDefinition(_ definition: CustomMetricDefinition) throws
    func reorder(_ ids: [String]) throws
    func persist(values: [CustomDailyValue], clearedIDs: Set<String>, on date: Date, log: DailyLog?) throws
}

final class CustomMetricsRepo: CustomMetricsRepositoryProtocol {
    static let shared = CustomMetricsRepo(databaseManager: DatabaseManager.shared)
    private let databaseManager: DatabaseManaging
    private let revisions: any AnalyticsRevisionProviding
    init(databaseManager: DatabaseManaging, revisions: any AnalyticsRevisionProviding = AnalyticsRevisionSource.shared) {
        self.databaseManager = databaseManager
        self.revisions = revisions
    }
    func definitions() throws -> [CustomMetricDefinition] {
        try databaseManager.read { try CustomMetricDefinition.order(Column("displayOrder"), Column("createdAt")).fetchAll($0) }
    }
    func values(on date: Date) throws -> [CustomDailyValue] {
        try databaseManager.read { try CustomDailyValue.filter(Column("dayKey") == LocalDayKey.make(for: date)).fetchAll($0) }
    }
    func allValues() throws -> [CustomDailyValue] {
        try databaseManager.read { try CustomDailyValue.order(Column("dayKey")).fetchAll($0) }
    }
    func hasHistory(_ id: String) throws -> Bool {
        try databaseManager.read { db in
            try CustomMetricDefinition.fetchOne(db, key: id)?.hasRecordedValues == true || CustomDailyValue.filter(Column("metricID") == id).fetchCount(db) > 0
        }
    }
    func saveDefinition(_ definition: CustomMetricDefinition) throws {
        var definition = definition
        definition.name = definition.name.trimmingCharacters(in: .whitespacesAndNewlines)
        definition.unit = definition.unit.trimmingCharacters(in: .whitespacesAndNewlines)
        if definition.kind != .number { definition.precision = 0 }
        if definition.kind != .number && definition.kind != .count { definition.unit = "" }
        if definition.kind != .rating { definition.ratingMin = 0; definition.ratingMax = 10 }
        try definition.validate()
        try databaseManager.write { db in
            let previous = try CustomMetricDefinition.fetchOne(db, key: definition.id)
            let hasValues = try CustomDailyValue.filter(Column("metricID") == definition.id).fetchCount(db) > 0
            if let previous, !definition.sameMeasurement(as: previous), previous.hasRecordedValues || hasValues {
                throw CustomMetricError.measurementLocked
            }
            definition.hasRecordedValues = previous?.hasRecordedValues == true || hasValues
            try definition.save(db)
            // Enable the group on first creation. Later edits never turn a hidden group back on.
            if previous == nil {
                var settings = try UserSettings.fetchOne(db) ?? .default
                settings.trackCustomMetrics = true
                try settings.save(db)
            }
        }
        revisions.bump(reason: .customMetric)
    }
    func reorder(_ ids: [String]) throws {
        try databaseManager.write { db in
            for (index, id) in ids.enumerated() {
                try db.execute(sql: "UPDATE customMetricDefinition SET displayOrder = ? WHERE id = ?", arguments: [index, id])
            }
        }
        revisions.bump(reason: .customMetric)
    }
    func persist(values: [CustomDailyValue], clearedIDs: Set<String>, on date: Date, log: DailyLog?) throws {
        let key = LocalDayKey.make(for: date)
        try databaseManager.write { db in
            // Validate every change before writing any of the check-in.
            for value in values {
                guard value.dayKey == key, let definition = try CustomMetricDefinition.fetchOne(db, key: value.metricID) else { throw CustomMetricError.missingDefinition }
                try value.validate(for: definition)
            }
            if let log { try log.upsert(db) }
            for id in clearedIDs {
                try db.execute(sql: "DELETE FROM customDailyValue WHERE metricID = ? AND dayKey = ?", arguments: [id, key])
            }
            for var value in values {
                let existing = try CustomDailyValue.filter(Column("metricID") == value.metricID && Column("dayKey") == key).fetchOne(db)
                value.createdAt = existing?.createdAt ?? value.createdAt
                value.updatedAt = Date()
                try value.save(db)
                try db.execute(sql: "UPDATE customMetricDefinition SET hasRecordedValues = 1 WHERE id = ?", arguments: [value.metricID])
            }
        }
        revisions.bump(reason: values.isEmpty && clearedIDs.isEmpty ? .dailyLog : .customMetric)
    }
}
