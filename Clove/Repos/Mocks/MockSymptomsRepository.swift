import Foundation

/// Mock implementation of SymptomsRepositoryProtocol for testing and previews
final class MockSymptomsRepository: SymptomsRepositoryProtocol {
    /// In-memory storage of symptoms
    var symptoms: [TrackedSymptom] = []

    /// Controls whether operations succeed or fail
    var shouldSucceed: Bool = true

    func getTrackedSymptoms() -> [TrackedSymptom] {
        return symptoms
    }

    func saveTrackedSymptoms(_ symptoms: [TrackedSymptom]) -> Bool {
        if shouldSucceed {
            self.symptoms = symptoms
            return true
        }
        return false
    }

    func saveSymptom(_ symptom: TrackedSymptom) -> Bool {
        if shouldSucceed {
            symptoms.append(symptom)
            return true
        }
        return false
    }

    func updateSymptom(id: Int64, name: String, isBinary: Bool) -> Bool {
        if shouldSucceed {
            if let index = symptoms.firstIndex(where: { $0.id == id }) {
                symptoms[index] = TrackedSymptom(id: id, name: name, isBinary: isBinary)
            }
            return true
        }
        return false
    }

    func deleteSymptom(id: Int64) -> Bool {
        if shouldSucceed {
            symptoms.removeAll { $0.id == id }
            return true
        }
        return false
    }

    /// Convenience factory for creating a mock with default symptoms
    static func withDefaultSymptoms() -> MockSymptomsRepository {
        let repo = MockSymptomsRepository()
        repo.symptoms = [
            TrackedSymptom(id: 1, name: "Headache", isBinary: false),
            TrackedSymptom(id: 2, name: "Fatigue", isBinary: false),
            TrackedSymptom(id: 3, name: "Nausea", isBinary: true),
            TrackedSymptom(id: 4, name: "Joint Pain", isBinary: false)
        ]
        return repo
    }
}
