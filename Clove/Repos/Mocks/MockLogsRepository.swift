import Foundation

/// Mock implementation of LogsRepositoryProtocol for testing and previews
final class MockLogsRepository: LogsRepositoryProtocol {
    /// In-memory storage of logs
    var logs: [DailyLog] = []

    /// Controls whether operations succeed or fail
    var shouldSucceed: Bool = true

    /// Tracks how many times saveLog was called
    var saveCallCount: Int = 0

    func saveLog(_ log: DailyLog) -> Bool {
        saveCallCount += 1
        if shouldSucceed {
            // Remove existing log for the same date if it exists
            let calendar = Calendar.current
            logs.removeAll { calendar.isDate($0.date, inSameDayAs: log.date) }
            logs.append(log)
            return true
        }
        return false
    }

    func getLogs() -> [DailyLog] {
        return logs
    }

    func getLogForDate(_ date: Date) -> DailyLog? {
        let calendar = Calendar.current
        return logs.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func getLogsInRange(from startDate: Date, to endDate: Date) -> [DailyLog] {
        return logs.filter { $0.date >= startDate && $0.date <= endDate }
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
