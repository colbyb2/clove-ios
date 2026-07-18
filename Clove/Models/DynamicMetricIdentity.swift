import Foundation
import GRDB

enum DynamicMetricFamily: String, Codable, Sendable {
    case symptom
    case medication
    case meal
    case activity
}

struct DynamicMetricIdentity: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var family: DynamicMetricFamily
    var displayName: String
    var normalizedName: String
    var isActive: Bool
    var createdAt: Date

    static let databaseTableName = "dynamicMetricIdentity"
}

struct MetricIdentityAlias: Codable, FetchableRecord, PersistableRecord {
    var aliasID: String
    var canonicalID: String
    var sourceName: String

    static let databaseTableName = "metricIdentityAlias"
}

enum DynamicMetricIdentityStore {
    static func resolveID(
        family: DynamicMetricFamily,
        name: String,
        in db: Database
    ) throws -> Int64 {
        let normalized = normalize(name)
        if let existing = try DynamicMetricIdentity
            .filter(Column("family") == family.rawValue && Column("normalizedName") == normalized)
            .fetchOne(db), let id = existing.id {
            return id
        }

        let identity = DynamicMetricIdentity(
            family: family,
            displayName: name,
            normalizedName: normalized,
            isActive: true,
            createdAt: Date()
        )
        try identity.insert(db)
        let id = db.lastInsertedRowID
        try registerAlias(family: family, sourceID: id, name: name, in: db)
        return id
    }

    static func updateDisplayName(
        family: DynamicMetricFamily,
        sourceID: Int64,
        name: String,
        in db: Database
    ) throws {
        try db.execute(
            sql: "UPDATE dynamicMetricIdentity SET displayName = ?, normalizedName = ?, isActive = 1 WHERE id = ? AND family = ?",
            arguments: [name, normalize(name), sourceID, family.rawValue]
        )
        try registerAlias(family: family, sourceID: sourceID, name: name, in: db)
    }

    static func registerAlias(
        family: DynamicMetricFamily,
        sourceID: Int64,
        name: String,
        in db: Database
    ) throws {
        let alias = MetricIdentityAlias(
            aliasID: legacyID(family: family, name: name),
            canonicalID: canonicalID(family: family, sourceID: sourceID).rawValue,
            sourceName: name
        )
        try alias.insert(db, onConflict: .ignore)
    }

    static func canonicalID(family: DynamicMetricFamily, sourceID: Int64) -> MetricID {
        MetricID(rawValue: "\(family.rawValue):\(sourceID)")
    }

    static func legacyID(family: DynamicMetricFamily, name: String) -> String {
        let prefix = family == .meal ? "meal" : family.rawValue
        return "\(prefix)_\(name.lowercased().replacingOccurrences(of: " ", with: "_"))"
    }

    static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
