import Foundation

/// Mock implementation of SymptomsRepositoryProtocol for testing and previews
final class MockSymptomsRepository: SymptomsRepositoryProtocol {
    /// In-memory storage of symptoms
    var symptoms: [TrackedSymptom] = []

    /// Controls whether operations succeed or fail
    var shouldSucceed: Bool = true
    var shouldReadSucceed: Bool = true

    func getTrackedSymptoms() -> [TrackedSymptom] {
        symptoms.sorted {
            $0.displayOrder == $1.displayOrder
                ? ($0.id ?? 0) < ($1.id ?? 0)
                : $0.displayOrder < $1.displayOrder
        }
    }

    func loadTrackedSymptoms() throws -> [TrackedSymptom] {
        guard shouldSucceed && shouldReadSucceed else {
            throw RepositoryError(
                operation: .read,
                resource: "tracked symptoms",
                diagnostic: "Injected mock read failure."
            )
        }
        return getTrackedSymptoms()
    }

    func saveTrackedSymptoms(_ symptoms: [TrackedSymptom]) -> Bool {
        if shouldSucceed {
            self.symptoms = symptoms.enumerated().map { index, symptom in
                var ordered = symptom
                ordered.displayOrder = index
                return ordered
            }
            return true
        }
        return false
    }

    func saveSymptom(_ symptom: TrackedSymptom) -> Bool {
        if shouldSucceed {
            var ordered = symptom
            ordered.displayOrder = (symptoms.map(\.displayOrder).max() ?? -1) + 1
            symptoms.append(ordered)
            return true
        }
        return false
    }

    func updateSymptom(id: Int64, name: String, isBinary: Bool) -> Bool {
        if shouldSucceed {
            if let index = symptoms.firstIndex(where: { $0.id == id }) {
                symptoms[index].name = name
                symptoms[index].isBinary = isBinary
            }
            return true
        }
        return false
    }

    func reorderSymptoms(_ symptoms: [TrackedSymptom]) -> Bool {
        guard shouldSucceed,
              Set(symptoms.compactMap(\.id)) == Set(self.symptoms.compactMap(\.id)),
              symptoms.count == self.symptoms.count else { return false }
        self.symptoms = symptoms.enumerated().map { index, symptom in
            var ordered = symptom
            ordered.displayOrder = index
            return ordered
        }
        return true
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
