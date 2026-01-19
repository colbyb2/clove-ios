import Foundation
import GRDB

@Observable
class MedicationRepository {
    static let shared = MedicationRepository()
    
    private let dbManager = DatabaseManager.shared
    
    private init() {}
    
    // MARK: - TrackedMedication Methods
    
    func getTrackedMedications() -> [TrackedMedication] {
        do {
            return try dbManager.read { db in
                try TrackedMedication.fetchAll(db)
            }
        } catch {
            print("Error loading tracked medications: \(error)")
            return []
        }
    }
    
    func saveMedication(_ medication: TrackedMedication) -> Bool {
        do {
            try dbManager.write { db in
                try medication.save(db)
            }
            return true
        } catch {
            print("Error saving medication: \(error)")
            return false
        }
    }
    
    func updateMedication(id: Int64, name: String, dosage: String, instructions: String, isAsNeeded: Bool) -> Bool {
        do {
            // Get the current medication to compare changes
            let currentMedication = try dbManager.read { db in
                try TrackedMedication.fetchOne(db, key: id)
            }
            
            guard let current = currentMedication else {
                print("Error: Medication with ID \(id) not found")
                return false
            }
            
            try dbManager.write { db in
                let medication = TrackedMedication(name: name, dosage: dosage, instructions: instructions, isAsNeeded: isAsNeeded)
                var updatedMedication = medication
                updatedMedication.id = id
                try updatedMedication.update(db)
                
                // Create history entries for changes
                try createUpdateHistoryEntries(
                    db: db,
                    medicationId: id,
                    medicationName: name,
                    current: current,
                    updated: updatedMedication
                )
            }
            return true
        } catch {
            print("Error updating medication: \(error)")
            return false
        }
    }
    
    func deleteMedication(id: Int64) -> Bool {
        do {
            // Get the medication before deleting it for history
            let medicationToDelete = try dbManager.read { db in
                try TrackedMedication.fetchOne(db, key: id)
            }
            
            guard let medication = medicationToDelete else {
                print("Error: Medication with ID \(id) not found")
                return false
            }
            
            try dbManager.write { db in
                // Create history entry for deletion
                let historyEntry = MedicationHistoryEntry(
                    medicationId: id,
                    medicationName: medication.name,
                    changeType: "removed",
                    oldValue: medication.name,
                    notes: "Medication removed from tracking"
                )
                try historyEntry.save(db)
                
                // Delete the medication
                try db.execute(sql: "DELETE FROM trackedMedication WHERE id = ?", arguments: [id])
            }
            return true
        } catch {
            print("Error deleting medication: \(error)")
            return false
        }
    }
    
    // MARK: - MedicationHistoryEntry Methods
    
    func getMedicationHistory(for medicationId: Int64? = nil) -> [MedicationHistoryEntry] {
        do {
            return try dbManager.read { db in
                if let medicationId = medicationId {
                    return try MedicationHistoryEntry.fetchAll(db, sql: "SELECT * FROM medicationHistoryEntry WHERE medicationId = ? ORDER BY changeDate DESC", arguments: [medicationId])
                } else {
                    return try MedicationHistoryEntry.fetchAll(db, sql: "SELECT * FROM medicationHistoryEntry ORDER BY changeDate DESC")
                }
            }
        } catch {
            print("Error loading medication history: \(error)")
            return []
        }
    }
    
    func addHistoryEntry(_ entry: MedicationHistoryEntry) -> Bool {
        do {
            try dbManager.write { db in
                try entry.save(db)
            }
            return true
        } catch {
            print("Error saving medication history entry: \(error)")
            return false
        }
    }
    
    // MARK: - Helper Methods for Automatic History Tracking
    
    func saveMedicationWithHistory(_ medication: TrackedMedication, changeType: String, oldValue: String? = nil, newValue: String? = nil) -> Bool {
        do {
            try dbManager.write { db in
                try medication.save(db)
                
                // Create history entry
                let historyEntry = MedicationHistoryEntry(
                    medicationId: medication.id ?? 0,
                    medicationName: medication.name,
                    changeType: changeType,
                    oldValue: oldValue,
                    newValue: newValue
                )
                try historyEntry.save(db)
            }
            return true
        } catch {
            print("Error saving medication with history: \(error)")
            return false
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func createUpdateHistoryEntries(db: Database, medicationId: Int64, medicationName: String, current: TrackedMedication, updated: TrackedMedication) throws {
        // Check for name changes
        if current.name != updated.name {
            let historyEntry = MedicationHistoryEntry(
                medicationId: medicationId,
                medicationName: medicationName,
                changeType: "name_changed",
                oldValue: current.name,
                newValue: updated.name
            )
            try historyEntry.save(db)
        }
        
        // Check for dosage changes
        if current.dosage != updated.dosage {
            let historyEntry = MedicationHistoryEntry(
                medicationId: medicationId,
                medicationName: medicationName,
                changeType: "dosage_changed",
                oldValue: current.dosage.isEmpty ? "No dosage" : current.dosage,
                newValue: updated.dosage.isEmpty ? "No dosage" : updated.dosage
            )
            try historyEntry.save(db)
        }
        
        // Check for instructions changes
        if current.instructions != updated.instructions {
            let historyEntry = MedicationHistoryEntry(
                medicationId: medicationId,
                medicationName: medicationName,
                changeType: "instructions_changed",
                oldValue: current.instructions.isEmpty ? "No instructions" : current.instructions,
                newValue: updated.instructions.isEmpty ? "No instructions" : updated.instructions
            )
            try historyEntry.save(db)
        }
        
        // Check for as-needed changes
        if current.isAsNeeded != updated.isAsNeeded {
            let historyEntry = MedicationHistoryEntry(
                medicationId: medicationId,
                medicationName: medicationName,
                changeType: "schedule_changed",
                oldValue: current.isAsNeeded ? "As needed" : "Regular schedule",
                newValue: updated.isAsNeeded ? "As needed" : "Regular schedule"
            )
            try historyEntry.save(db)
        }
    }
    
    // MARK: - Adherence Calculation Methods
    
    func calculateAdherencePercentage(for medicationId: Int64, days: Int = 30) -> Double {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let endDate = Date()
        
        do {
            let logs = try dbManager.read { db in
                try DailyLog.fetchAll(db, sql: "SELECT * FROM dailyLog WHERE date >= ? AND date <= ?", arguments: [startDate, endDate])
            }
            
            var totalDays = 0
            var takenDays = 0
            
            for log in logs {
                let adherence = log.medicationAdherence
                if let medicationAdherence = adherence.first(where: { $0.medicationId == medicationId }) {
                    totalDays += 1
                    if medicationAdherence.wasTaken {
                        takenDays += 1
                    }
                }
            }
            
            guard totalDays > 0 else { return 0.0 }
            return Double(takenDays) / Double(totalDays) * 100.0
            
        } catch {
            print("Error calculating adherence percentage: \(error)")
            return 0.0
        }
    }
    
    func calculateOverallAdherencePercentage(days: Int = 30) -> Double {
        let trackedMedications = getTrackedMedications()
        // Filter out as-needed medications from adherence calculation
        let regularMedications = trackedMedications.filter { !$0.isAsNeeded }
        guard !regularMedications.isEmpty else { return 0.0 }
        
        let adherencePercentages = regularMedications.compactMap { medication -> Double? in
            guard let id = medication.id else { return nil }
            return calculateAdherencePercentage(for: id, days: days)
        }
        
        guard !adherencePercentages.isEmpty else { return 0.0 }
        return adherencePercentages.reduce(0, +) / Double(adherencePercentages.count)
    }
    
    func getAdherenceInsights(days: Int = 30) -> [String: Any] {
        let trackedMedications = getTrackedMedications()
        // Filter out as-needed medications from adherence insights
        let regularMedications = trackedMedications.filter { !$0.isAsNeeded }
        var insights: [String: Any] = [:]
        
        let overallPercentage = calculateOverallAdherencePercentage(days: days)
        insights["overallPercentage"] = overallPercentage
        
        var medicationBreakdown: [[String: Any]] = []
        for medication in regularMedications {
            guard let id = medication.id else { continue }
            let percentage = calculateAdherencePercentage(for: id, days: days)
            medicationBreakdown.append([
                "name": medication.name,
                "percentage": percentage,
                "id": id,
                "isAsNeeded": medication.isAsNeeded
            ])
        }
        
        insights["medicationBreakdown"] = medicationBreakdown
        insights["totalMedications"] = regularMedications.count
        insights["totalMedicationsIncludingAsNeeded"] = trackedMedications.count
        
        return insights
    }
}

// MARK: - Protocol Conformance
extension MedicationRepository: MedicationRepositoryProtocol {}