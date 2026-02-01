import Foundation

/// Protocol defining operations for medication tracking management
protocol MedicationRepositoryProtocol {
    // MARK: - TrackedMedication Methods

    /// Retrieves all tracked medications
    /// - Returns: Array of tracked medications
    func getTrackedMedications() -> [TrackedMedication]

    /// Saves a medication
    /// - Parameter medication: The medication to save
    /// - Returns: True if successful, false otherwise
    func saveMedication(_ medication: TrackedMedication) -> Bool

    /// Updates an existing medication
    /// - Parameters:
    ///   - id: The ID of the medication to update
    ///   - name: The new name
    ///   - dosage: The new dosage
    ///   - instructions: The new instructions
    ///   - isAsNeeded: Whether the medication is taken as needed
    /// - Returns: True if successful, false otherwise
    func updateMedication(id: Int64, name: String, dosage: String, instructions: String, isAsNeeded: Bool) -> Bool

    /// Deletes a medication
    /// - Parameter id: The ID of the medication to delete
    /// - Returns: True if successful, false otherwise
    func deleteMedication(id: Int64) -> Bool

    // MARK: - MedicationHistoryEntry Methods

    /// Retrieves medication history entries
    /// - Parameter medicationId: Optional medication ID to filter by
    /// - Returns: Array of history entries
    func getMedicationHistory(for medicationId: Int64?) -> [MedicationHistoryEntry]

    /// Adds a history entry
    /// - Parameter entry: The history entry to add
    /// - Returns: True if successful, false otherwise
    func addHistoryEntry(_ entry: MedicationHistoryEntry) -> Bool

    /// Saves a medication with an associated history entry
    /// - Parameters:
    ///   - medication: The medication to save
    ///   - changeType: The type of change
    ///   - oldValue: The old value (optional)
    ///   - newValue: The new value (optional)
    /// - Returns: True if successful, false otherwise
    func saveMedicationWithHistory(_ medication: TrackedMedication, changeType: String, oldValue: String?, newValue: String?) -> Bool

    // MARK: - Adherence Calculation Methods

    /// Calculates adherence percentage for a specific medication
    /// - Parameters:
    ///   - medicationId: The medication ID
    ///   - days: Number of days to calculate over (default: 30)
    /// - Returns: Adherence percentage (0-100)
    func calculateAdherencePercentage(for medicationId: Int64, days: Int) -> Double

    /// Calculates overall adherence percentage across all regular medications
    /// - Parameter days: Number of days to calculate over (default: 30)
    /// - Returns: Overall adherence percentage (0-100)
    func calculateOverallAdherencePercentage(days: Int) -> Double

    /// Gets detailed adherence insights
    /// - Parameter days: Number of days to analyze (default: 30)
    /// - Returns: Dictionary containing adherence insights
    func getAdherenceInsights(days: Int) -> [String: Any]
}
