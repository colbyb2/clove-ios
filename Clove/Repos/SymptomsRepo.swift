import Foundation
import GRDB

class SymptomsRepo {
    static let shared = SymptomsRepo()

    private let dbManager = DatabaseManager.shared

    func getTrackedSymptoms() -> [TrackedSymptom] {
        do {
            return try dbManager.read { db in
                try TrackedSymptom.fetchAll(db)
            }
        } catch {
            print("Error loading tracked symptoms: \(error)")
            return []
        }
    }

    func saveTrackedSymptoms(_ symptoms: [TrackedSymptom]) -> Bool {
        do {
            try dbManager.write { db in
                try symptoms.forEach { try $0.save(db) }
            }
            return true
        } catch {
            print("Error saving tracked symptoms: \(error)")
            return false
        }
    }
    
    func saveSymptom(_ symptom: TrackedSymptom) -> Bool {
        do {
            try dbManager.write { db in
                try symptom.save(db)
            }
            return true
        } catch {
            print("Error saving symptom: \(error)")
            return false
        }
    }
    
    func updateSymptom(id: Int64, name: String, isBinary: Bool) -> Bool {
        do {
            try dbManager.write { db in
                let symptom = TrackedSymptom(id: id, name: name, isBinary: isBinary)
                try symptom.update(db)
            }
            return true
        } catch {
            print("Error updating symptom: \(error)")
            return false
        }
    }
    
    func deleteSymptom(id: Int64) -> Bool {
        do {
            try dbManager.write { db in
                try db.execute(sql: "DELETE FROM trackedSymptom WHERE id = ?", arguments: [id])
            }
            return true
        } catch {
            print("Error deleting symptom: \(error)")
            return false
        }
    }
}
