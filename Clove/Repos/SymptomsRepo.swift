import Foundation
import GRDB

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
                try TrackedSymptom.fetchAll(db)
            }
        } catch {
            print("Error loading tracked symptoms: \(error)")
            return []
        }
    }

    func saveTrackedSymptoms(_ symptoms: [TrackedSymptom]) -> Bool {
        do {
            try databaseManager.write { db in
                for symptom in symptoms {
                    let saved = symptom
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
                let saved = symptom
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
                let symptom = TrackedSymptom(id: id, name: name, isBinary: isBinary)
                try symptom.update(db)
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
    
    func deleteSymptom(id: Int64) -> Bool {
        do {
            try databaseManager.write { db in
                try db.execute(sql: "DELETE FROM trackedSymptom WHERE id = ?", arguments: [id])
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
