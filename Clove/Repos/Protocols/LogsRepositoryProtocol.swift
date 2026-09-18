import Foundation

/// Protocol defining operations for daily log management
protocol LogsRepositoryProtocol {
    /// Throwing variants let user-facing screens distinguish a database failure
    /// from a successful query that simply has no records.
    func loadLogs() throws -> [DailyLog]
    func loadLog(for date: Date) throws -> DailyLog?
    func loadLogsInRange(from startDate: Date, to endDate: Date) throws -> [DailyLog]
    func persistLog(_ log: DailyLog) throws
    func persistWaterIntake(_ ounces: Int?, for date: Date) throws

    /// Saves a daily log, updating existing log if one exists for the date
    /// - Parameter log: The log to save
    /// - Returns: True if successful, false otherwise
    func saveLog(_ log: DailyLog) -> Bool

    /// Saves only hydration for a date without overwriting other daily-log fields.
    func saveWaterIntake(_ ounces: Int?, for date: Date) -> Bool

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

extension LogsRepositoryProtocol {
    func loadLogs() throws -> [DailyLog] { getLogs() }

    func loadLog(for date: Date) throws -> DailyLog? { getLogForDate(date) }

    func loadLogsInRange(from startDate: Date, to endDate: Date) throws -> [DailyLog] {
        getLogsInRange(from: startDate, to: endDate)
    }

    func persistLog(_ log: DailyLog) throws {
        guard saveLog(log) else {
            throw RepositoryError(
                operation: .write,
                resource: "daily log",
                diagnostic: "The repository reported an unsuccessful save."
            )
        }
    }

    func persistWaterIntake(_ ounces: Int?, for date: Date) throws {
        guard saveWaterIntake(ounces, for: date) else {
            throw RepositoryError(
                operation: .write,
                resource: "hydration",
                diagnostic: "The repository reported an unsuccessful save."
            )
        }
    }
}
