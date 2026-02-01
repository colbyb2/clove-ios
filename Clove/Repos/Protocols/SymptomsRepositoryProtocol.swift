import Foundation

/// Protocol defining operations for symptom tracking management
protocol SymptomsRepositoryProtocol {
    /// Retrieves all tracked symptoms
    /// - Returns: Array of tracked symptoms
    func getTrackedSymptoms() -> [TrackedSymptom]

    /// Saves multiple tracked symptoms
    /// - Parameter symptoms: The symptoms to save
    /// - Returns: True if successful, false otherwise
    func saveTrackedSymptoms(_ symptoms: [TrackedSymptom]) -> Bool

    /// Saves a single symptom
    /// - Parameter symptom: The symptom to save
    /// - Returns: True if successful, false otherwise
    func saveSymptom(_ symptom: TrackedSymptom) -> Bool

    /// Updates an existing symptom
    /// - Parameters:
    ///   - id: The ID of the symptom to update
    ///   - name: The new name
    ///   - isBinary: Whether the symptom is binary (yes/no) or rated (1-10)
    /// - Returns: True if successful, false otherwise
    func updateSymptom(id: Int64, name: String, isBinary: Bool) -> Bool

    /// Deletes a symptom
    /// - Parameter id: The ID of the symptom to delete
    /// - Returns: True if successful, false otherwise
    func deleteSymptom(id: Int64) -> Bool
}
