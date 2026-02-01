import Foundation

/// Protocol defining operations for bowel movement tracking
protocol BowelMovementRepositoryProtocol {
    /// Saves multiple bowel movements
    /// - Parameter bowelMovements: The bowel movements to save
    /// - Returns: True if successful, false otherwise
    func save(_ bowelMovements: [BowelMovement]) -> Bool

    /// Deletes a bowel movement
    /// - Parameter id: The ID of the bowel movement to delete
    /// - Returns: True if successful, false otherwise
    func delete(id: Int64) -> Bool

    /// Retrieves bowel movements for a specific date
    /// - Parameter date: The date to search for
    /// - Returns: Array of bowel movements for that date
    func getBowelMovementsForDate(_ date: Date) -> [BowelMovement]

    /// Retrieves all bowel movements
    /// - Returns: Array of all bowel movements
    func getAllBowelMovements() -> [BowelMovement]

    /// Retrieves bowel movements for a time period
    /// - Parameter period: The time period to search
    /// - Returns: Array of bowel movements within the period
    func getBowelMovements(for period: TimePeriod) -> [BowelMovement]
}
