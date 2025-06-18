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
}