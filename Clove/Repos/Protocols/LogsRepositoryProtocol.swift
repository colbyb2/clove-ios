import Foundation

/// Protocol defining operations for daily log management
protocol LogsRepositoryProtocol: Sendable {
    /// Saves a daily log, updating existing log if one exists for the date
    /// - Parameter log: The log to save
    /// - Returns: True if successful, false otherwise
    func saveLog(_ log: DailyLog) -> Bool

    /// Retrieves all daily logs
    /// - Returns: Array of all daily logs
    func getLogs() -> [DailyLog]

    /// Retrieves the log for a specific date
    /// - Parameter date: The date to search for
    /// - Returns: The log if found, nil otherwise
    func getLogForDate(_ date: Date) -> DailyLog?

    /// Retrieves logs within a date range
    /// - Parameters:
    ///   - startDate: The start of the date range
    ///   - endDate: The end of the date range
    /// - Returns: Array of logs within the range
    func getLogsInRange(from startDate: Date, to endDate: Date) -> [DailyLog]
}
