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
            return try databaseManager.read { db in
                try TrackedSymptom
                    .order(Column("displayOrder").asc, Column("id").asc)
                    .fetchAll(db)
            }
        } catch {
            print("Error loading tracked symptoms: \(error)")
            return []
        }
    }

    func saveTrackedSymptoms(_ symptoms: [TrackedSymptom]) -> Bool {
        do {
            try databaseManager.write { db in
                for (displayOrder, symptom) in symptoms.enumerated() {
                    var saved = symptom
                    saved.displayOrder = displayOrder
                    try saved.save(db)
                    let id = saved.id ?? db.lastInsertedRowID
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
                    saved.displayOrder = (try Int.fetchOne(
                        db,
                        sql: "SELECT MAX(displayOrder) FROM trackedSymptom"
                    ) ?? -1) + 1
                }
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
                    sql: "UPDATE trackedSymptom SET name = ?, isBinary = ? WHERE id = ?",
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
                    sql: "SELECT id FROM trackedSymptom ORDER BY displayOrder ASC, id ASC"
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
                try db.execute(sql: "DELETE FROM trackedSymptom WHERE id = ?", arguments: [id])
                let remainingIDs = try Int64.fetchAll(
                    db,
                    sql: "SELECT id FROM trackedSymptom ORDER BY displayOrder ASC, id ASC"
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
