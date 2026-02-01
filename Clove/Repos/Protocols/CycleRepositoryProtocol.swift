import Foundation

/// Protocol defining operations for cycle tracking
protocol CycleRepositoryProtocol {
    /// Saves multiple cycle entries
    /// - Parameter cycles: The cycle entries to save
    /// - Returns: True if successful, false otherwise
    func save(_ cycles: [Cycle]) -> Bool

    /// Deletes a cycle entry
    /// - Parameter id: The ID of the cycle entry to delete
    /// - Returns: True if successful, false otherwise
    func delete(id: Int64) -> Bool

    /// Retrieves cycle entries for a specific date
    /// - Parameter date: The date to search for
    /// - Returns: Array of cycle entries for that date
    func getCyclesForDate(_ date: Date) -> [Cycle]

    /// Retrieves all cycle entries
    /// - Returns: Array of all cycle entries
    func getAllCycles() -> [Cycle]

    /// Retrieves cycle entries for a time period
    /// - Parameter period: The time period to search
    /// - Returns: Array of cycle entries within the period
    func getCycles(for period: TimePeriod) -> [Cycle]
}
