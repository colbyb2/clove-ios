import Foundation

/// Protocol defining operations for food entry tracking
protocol FoodEntryRepositoryProtocol {
    /// Saves a food entry
    /// - Parameter entry: The food entry to save
    /// - Returns: The saved entry with ID populated, or nil on failure
    @discardableResult
    func save(_ entry: FoodEntry) -> FoodEntry?

    /// Saves multiple food entries
    /// - Parameter entries: The food entries to save
    /// - Returns: True if successful, false otherwise
    func save(_ entries: [FoodEntry]) -> Bool

    /// Updates an existing food entry
    /// - Parameter entry: The food entry to update (must have valid ID)
    /// - Returns: True if successful, false otherwise
    func update(_ entry: FoodEntry) -> Bool

    /// Deletes a food entry by ID
    /// - Parameter id: The ID of the food entry to delete
    /// - Returns: True if successful, false otherwise
    func delete(id: Int64) -> Bool

    /// Retrieves food entries for a specific date
    /// - Parameter date: The date to search for
    /// - Returns: Array of food entries for that date, ordered by time
    func getEntriesForDate(_ date: Date) -> [FoodEntry]

    /// Retrieves all food entries
    /// - Returns: Array of all food entries, ordered by date descending
    func getAllEntries() -> [FoodEntry]

    /// Retrieves food entries for a time period
    /// - Parameter period: The time period to search
    /// - Returns: Array of food entries within the period
    func getEntries(for period: TimePeriod) -> [FoodEntry]

    /// Retrieves favorite food entries for quick-add
    /// - Returns: Array of favorite food entries
    func getFavorites() -> [FoodEntry]

    /// Retrieves recent unique food names for suggestions
    /// - Parameter limit: Maximum number of suggestions to return
    /// - Returns: Array of unique food names, most recent first
    func getRecentFoodNames(limit: Int) -> [String]

    /// Retrieves food entries grouped by category for a specific date
    /// - Parameter date: The date to search for
    /// - Returns: Dictionary mapping categories to arrays of food entries
    func getEntriesGroupedByCategory(for date: Date) -> [MealCategory: [FoodEntry]]

    /// Toggles the favorite status of a food entry
    /// - Parameter id: The ID of the food entry
    /// - Returns: True if successful, false otherwise
    func toggleFavorite(id: Int64) -> Bool

    /// Searches food entries by name
    /// - Parameter query: The search query
    /// - Returns: Array of matching food entries
    func search(query: String) -> [FoodEntry]
}
