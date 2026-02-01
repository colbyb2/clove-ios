import Foundation

/// Protocol defining operations for activity entry tracking
protocol ActivityEntryRepositoryProtocol {
    /// Saves an activity entry
    /// - Parameter entry: The activity entry to save
    /// - Returns: The saved entry with ID populated, or nil on failure
    @discardableResult
    func save(_ entry: ActivityEntry) -> ActivityEntry?

    /// Saves multiple activity entries
    /// - Parameter entries: The activity entries to save
    /// - Returns: True if successful, false otherwise
    func save(_ entries: [ActivityEntry]) -> Bool

    /// Updates an existing activity entry
    /// - Parameter entry: The activity entry to update (must have valid ID)
    /// - Returns: True if successful, false otherwise
    func update(_ entry: ActivityEntry) -> Bool

    /// Deletes an activity entry by ID
    /// - Parameter id: The ID of the activity entry to delete
    /// - Returns: True if successful, false otherwise
    func delete(id: Int64) -> Bool

    /// Retrieves activity entries for a specific date
    /// - Parameter date: The date to search for
    /// - Returns: Array of activity entries for that date, ordered by time
    func getEntriesForDate(_ date: Date) -> [ActivityEntry]

    /// Retrieves all activity entries
    /// - Returns: Array of all activity entries, ordered by date descending
    func getAllEntries() -> [ActivityEntry]

    /// Retrieves activity entries for a time period
    /// - Parameter period: The time period to search
    /// - Returns: Array of activity entries within the period
    func getEntries(for period: TimePeriod) -> [ActivityEntry]

    /// Retrieves favorite activity entries for quick-add
    /// - Returns: Array of favorite activity entries
    func getFavorites() -> [ActivityEntry]

    /// Retrieves recent unique activity names for suggestions
    /// - Parameter limit: Maximum number of suggestions to return
    /// - Returns: Array of unique activity names, most recent first
    func getRecentActivityNames(limit: Int) -> [String]

    /// Retrieves activity entries grouped by category for a specific date
    /// - Parameter date: The date to search for
    /// - Returns: Dictionary mapping categories to arrays of activity entries
    func getEntriesGroupedByCategory(for date: Date) -> [ActivityCategory: [ActivityEntry]]

    /// Toggles the favorite status of an activity entry
    /// - Parameter id: The ID of the activity entry
    /// - Returns: True if successful, false otherwise
    func toggleFavorite(id: Int64) -> Bool

    /// Searches activity entries by name
    /// - Parameter query: The search query
    /// - Returns: Array of matching activity entries
    func search(query: String) -> [ActivityEntry]

    /// Gets total duration of activities for a specific date
    /// - Parameter date: The date to calculate for
    /// - Returns: Total duration in minutes
    func getTotalDuration(for date: Date) -> Int
}
