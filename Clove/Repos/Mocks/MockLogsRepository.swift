import Foundation

/// Mock implementation of LogsRepositoryProtocol for testing and previews
final class MockLogsRepository: LogsRepositoryProtocol {
    /// In-memory storage of logs
    var logs: [DailyLog] = []

    /// Controls whether operations succeed or fail
    var shouldSucceed: Bool = true
    var shouldReadSucceed: Bool = true
    var shouldWriteSucceed: Bool = true

    /// Tracks how many times saveLog was called
    var saveCallCount: Int = 0

    func saveLog(_ log: DailyLog) -> Bool {
        saveCallCount += 1
        if shouldSucceed && shouldWriteSucceed {
            var normalized = log
            normalized.dayKey = LocalDayKey.make(for: log.date)
            logs.removeAll { $0.dayKey == normalized.dayKey }
            logs.append(normalized)
            return true
        }
        return false
    }

    func saveWaterIntake(_ ounces: Int?, for date: Date) -> Bool {
        guard shouldSucceed && shouldWriteSucceed else { return false }

        let dayKey = LocalDayKey.make(for: date)
        if let index = logs.firstIndex(where: { $0.dayKey == dayKey }) {
            logs[index].waterIntake = ounces
        } else if let ounces {
            logs.append(DailyLog(date: date, waterIntake: ounces))
        }
        return true
    }

    func getLogs() -> [DailyLog] {
        return logs
    }

    func getLogForDate(_ date: Date) -> DailyLog? {
        let dayKey = LocalDayKey.make(for: date)
        return logs.first { $0.dayKey == dayKey }
    }

    func getLogsInRange(from startDate: Date, to endDate: Date) -> [DailyLog] {
        let startKey = LocalDayKey.make(for: startDate)
        let endKey = LocalDayKey.make(for: endDate)
        return logs.filter { $0.dayKey >= startKey && $0.dayKey <= endKey }
    }

    func loadLogs() throws -> [DailyLog] {
        try requireReadable(resource: "daily logs")
        return logs
    }

    func loadLog(for date: Date) throws -> DailyLog? {
        try requireReadable(resource: "daily log")
        return getLogForDate(date)
    }

    func loadLogsInRange(from startDate: Date, to endDate: Date) throws -> [DailyLog] {
        try requireReadable(resource: "daily logs")
        return getLogsInRange(from: startDate, to: endDate)
    }

    func persistLog(_ log: DailyLog) throws {
        guard saveLog(log) else {
            throw RepositoryError(
                operation: .write,
                resource: "daily log",
                diagnostic: "Injected mock write failure."
            )
        }
    }

    func persistWaterIntake(_ ounces: Int?, for date: Date) throws {
        guard saveWaterIntake(ounces, for: date) else {
            throw RepositoryError(
                operation: .write,
                resource: "hydration",
                diagnostic: "Injected mock write failure."
            )
        }
    }

    private func requireReadable(resource: String) throws {
        guard shouldSucceed && shouldReadSucceed else {
            throw RepositoryError(
                operation: .read,
                resource: resource,
                diagnostic: "Injected mock read failure."
            )
        }
    }

    /// Convenience factory for creating a mock with sample data
    static func withSampleData(days: Int = 30) -> MockLogsRepository {
        let repo = MockLogsRepository()
        let calendar = Calendar.current

        for daysAgo in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) {
                let log = DailyLog(
                    date: date,
                    mood: Int.random(in: 1...10),
                    painLevel: Int.random(in: 1...10),
                    energyLevel: Int.random(in: 1...10),
                    meals: ["Breakfast", "Lunch", "Dinner"].shuffled().prefix(Int.random(in: 1...3)).map { $0 },
                    activities: ["Walking", "Reading", "Exercise"].shuffled().prefix(Int.random(in: 0...2)).map { $0 },
                    isFlareDay: Bool.random()
                )
                repo.logs.append(log)
            }
        }

        return repo
    }
}
