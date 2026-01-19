import Foundation

/// Mock implementation of MedicationRepositoryProtocol for testing and previews
final class MockMedicationRepository: MedicationRepositoryProtocol {
    /// In-memory storage of medications
    var medications: [TrackedMedication] = []

    /// In-memory storage of history entries
    var historyEntries: [MedicationHistoryEntry] = []

    /// Controls whether operations succeed or fail
    var shouldSucceed: Bool = true

    // MARK: - TrackedMedication Methods

    func getTrackedMedications() -> [TrackedMedication] {
        return medications
    }

    func saveMedication(_ medication: TrackedMedication) -> Bool {
        if shouldSucceed {
            medications.append(medication)
            return true
        }
        return false
    }

    func updateMedication(id: Int64, name: String, dosage: String, instructions: String, isAsNeeded: Bool) -> Bool {
        if shouldSucceed {
            if let index = medications.firstIndex(where: { $0.id == id }) {
                var updatedMedication = TrackedMedication(
                    name: name,
                    dosage: dosage,
                    instructions: instructions,
                    isAsNeeded: isAsNeeded
                )
                updatedMedication.id = id
                medications[index] = updatedMedication
            }
            return true
        }
        return false
    }

    func deleteMedication(id: Int64) -> Bool {
        if shouldSucceed {
            medications.removeAll { $0.id == id }
            return true
        }
        return false
    }

    // MARK: - MedicationHistoryEntry Methods

    func getMedicationHistory(for medicationId: Int64?) -> [MedicationHistoryEntry] {
        if let medicationId = medicationId {
            return historyEntries.filter { $0.medicationId == medicationId }
        }
        return historyEntries
    }

    func addHistoryEntry(_ entry: MedicationHistoryEntry) -> Bool {
        if shouldSucceed {
            historyEntries.append(entry)
            return true
        }
        return false
    }

    func saveMedicationWithHistory(_ medication: TrackedMedication, changeType: String, oldValue: String?, newValue: String?) -> Bool {
        if shouldSucceed {
            medications.append(medication)
            let entry = MedicationHistoryEntry(
                medicationId: medication.id ?? 0,
                medicationName: medication.name,
                changeType: changeType,
                oldValue: oldValue,
                newValue: newValue
            )
            historyEntries.append(entry)
            return true
        }
        return false
    }

    // MARK: - Adherence Calculation Methods

    func calculateAdherencePercentage(for medicationId: Int64, days: Int) -> Double {
        // Simple mock implementation
        return Double.random(in: 60...95)
    }

    func calculateOverallAdherencePercentage(days: Int) -> Double {
        // Simple mock implementation
        return Double.random(in: 70...90)
    }

    func getAdherenceInsights(days: Int) -> [String: Any] {
        // Simple mock implementation
        return [
            "overallPercentage": 85.0,
            "totalMedications": medications.count,
            "medicationBreakdown": []
        ]
    }

    /// Convenience factory for creating a mock with sample medications
    static func withSampleMedications() -> MockMedicationRepository {
        let repo = MockMedicationRepository()

        var med1 = TrackedMedication(name: "Medication A", dosage: "10mg", instructions: "Take with food", isAsNeeded: false)
        med1.id = 1

        var med2 = TrackedMedication(name: "Medication B", dosage: "5mg", instructions: "Take before bed", isAsNeeded: false)
        med2.id = 2

        var med3 = TrackedMedication(name: "Pain Reliever", dosage: "As needed", instructions: "For pain", isAsNeeded: true)
        med3.id = 3

        repo.medications = [med1, med2, med3]
        return repo
    }
}
