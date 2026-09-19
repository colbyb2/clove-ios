import Foundation
import GRDB

private enum SymptomsRepoError: Error {
    case invalidReorder
}

final class SymptomsRepo {
    static let shared = SymptomsRepo(databaseManager: DatabaseManager.shared)

    private let databaseManager: DatabaseManaging
    private let analyticsRevisionSource: any AnalyticsRevisionProviding

    init(
        databaseManager: DatabaseManaging,
        analyticsRevisionSource: any AnalyticsRevisionProviding = AnalyticsRevisionSource.shared
    ) {
        self.databaseManager = databaseManager
        self.analyticsRevisionSource = analyticsRevisionSource
    }

    func getTrackedSymptoms() -> [TrackedSymptom] {
        do {
            return try loadTrackedSymptoms()
        } catch {
            print("Error loading tracked symptoms: \(error)")
            return []
        }
    }

    func loadTrackedSymptoms() throws -> [TrackedSymptom] {
        do {
            return try databaseManager.read { db in
                try TrackedSymptom
                    .filter(Column("isActive") == true)
                    .order(Column("displayOrder").asc, Column("id").asc)
                    .fetchAll(db)
            }
        } catch {
            throw RepositoryError(operation: .read, resource: "tracked symptoms", underlyingError: error)
        }
    }

    func getAllSymptoms() -> [TrackedSymptom] {
        do {
            return try databaseManager.read { db in
                try TrackedSymptom
                    .order(Column("displayOrder").asc, Column("id").asc)
                    .fetchAll(db)
            }
        } catch {
            print("Error loading symptom history: \(error)")
            return []
        }
    }

    func saveTrackedSymptoms(_ symptoms: [TrackedSymptom]) -> Bool {
        do {
            try databaseManager.write { db in
                for (displayOrder, symptom) in symptoms.enumerated() {
                    var saved = symptom
                    saved.displayOrder = displayOrder
                    saved.isActive = true
                    try saved.save(db)
                    let id = saved.id ?? db.lastInsertedRowID
                    try db.execute(
                        sql: "UPDATE trackedSymptom SET isActive = 1 WHERE id = ?",
                        arguments: [id]
                    )
                    try DynamicMetricIdentityStore.registerAlias(
                        family: .symptom,
                        sourceID: id,
                        name: saved.name,
                        in: db
                    )
                }
            }
            analyticsRevisionSource.bump(reason: .symptomDefinition)
            return true
        } catch {
            print("Error saving tracked symptoms: \(error)")
            return false
        }
    }
    
    func saveSymptom(_ symptom: TrackedSymptom) -> Bool {
        do {
            try databaseManager.write { db in
                var saved = symptom
                if saved.id == nil {
                    let normalizedName = saved.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if var inactive = try TrackedSymptom
                        .filter(Column("isActive") == false)
                        .fetchAll(db)
                        .first(where: {
                            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedName
                        }) {
                        inactive.name = saved.name
                        inactive.isBinary = saved.isBinary
                        inactive.isActive = true
                        inactive.displayOrder = (try Int.fetchOne(
                            db,
                            sql: "SELECT MAX(displayOrder) FROM trackedSymptom WHERE isActive = 1"
                        ) ?? -1) + 1
                        try db.execute(
                            sql: "UPDATE trackedSymptom SET name = ?, isBinary = ?, displayOrder = ?, isActive = 1 WHERE id = ?",
                            arguments: [inactive.name, inactive.isBinary, inactive.displayOrder, inactive.id]
                        )
                        try DynamicMetricIdentityStore.registerAlias(
                            family: .symptom,
                            sourceID: inactive.id!,
                            name: inactive.name,
                            in: db
                        )
                        return
                    }
                    saved.displayOrder = (try Int.fetchOne(
                        db,
                        sql: "SELECT MAX(displayOrder) FROM trackedSymptom WHERE isActive = 1"
                    ) ?? -1) + 1
                }
                saved.isActive = true
                try saved.save(db)
                let id = saved.id ?? db.lastInsertedRowID
                try DynamicMetricIdentityStore.registerAlias(
                    family: .symptom,
                    sourceID: id,
                    name: saved.name,
                    in: db
                )
            }
            analyticsRevisionSource.bump(reason: .symptomDefinition)
            return true
        } catch {
            print("Error saving symptom: \(error)")
            return false
        }
    }
    
    func updateSymptom(id: Int64, name: String, isBinary: Bool) -> Bool {
        do {
            try databaseManager.write { db in
                try db.execute(
                    sql: "UPDATE trackedSymptom SET name = ?, isBinary = ?, isActive = 1 WHERE id = ?",
                    arguments: [name, isBinary, id]
                )
                try DynamicMetricIdentityStore.registerAlias(
                    family: .symptom,
                    sourceID: id,
                    name: name,
                    in: db
                )
            }
            analyticsRevisionSource.bump(reason: .symptomDefinition)
            return true
        } catch {
            print("Error updating symptom: \(error)")
            return false
        }
    }

    func reorderSymptoms(_ symptoms: [TrackedSymptom]) -> Bool {
        do {
            try databaseManager.write { db in
                let requestedIDs = symptoms.compactMap(\.id)
                let storedIDs = try Int64.fetchAll(
                    db,
                    sql: "SELECT id FROM trackedSymptom WHERE isActive = 1 ORDER BY displayOrder ASC, id ASC"
                )
                guard requestedIDs.count == symptoms.count,
                      Set(requestedIDs) == Set(storedIDs),
                      requestedIDs.count == storedIDs.count else {
                    throw SymptomsRepoError.invalidReorder
                }
                for (displayOrder, id) in requestedIDs.enumerated() {
                    try db.execute(
                        sql: "UPDATE trackedSymptom SET displayOrder = ? WHERE id = ?",
                        arguments: [displayOrder, id]
                    )
                }
            }
            analyticsRevisionSource.bump(reason: .symptomDefinition)
            return true
        } catch {
            print("Error reordering tracked symptoms: \(error)")
            return false
        }
    }
    
    func deleteSymptom(id: Int64) -> Bool {
        do {
            try databaseManager.write { db in
                try db.execute(sql: "UPDATE trackedSymptom SET isActive = 0 WHERE id = ?", arguments: [id])
                let remainingIDs = try Int64.fetchAll(
                    db,
                    sql: "SELECT id FROM trackedSymptom WHERE isActive = 1 ORDER BY displayOrder ASC, id ASC"
                )
                for (displayOrder, remainingID) in remainingIDs.enumerated() {
                    try db.execute(
                        sql: "UPDATE trackedSymptom SET displayOrder = ? WHERE id = ?",
                        arguments: [displayOrder, remainingID]
                    )
                }
            }
            analyticsRevisionSource.bump(reason: .symptomDefinition)
            return true
        } catch {
            print("Error deleting symptom: \(error)")
            return false
        }
    }
}

// MARK: - Protocol Conformance
extension SymptomsRepo: SymptomsRepositoryProtocol {}
