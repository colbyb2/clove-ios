import Foundation

final class MockHistoryDaySummaryRepository: HistoryDaySummaryRepositoryProtocol {
    var summaries: [Date: HistoryDaySummary]
    var shouldReadSucceed = true

    init(
        logs: [DailyLog] = [],
        foodEntries: [FoodEntry] = [],
        activityEntries: [ActivityEntry] = [],
        bowelMovements: [BowelMovement] = [],
        calendar: Calendar = .current
    ) {
        var summaries: [Date: HistoryDaySummary] = [:]
        for log in logs {
            let day = log.date(in: calendar)
            summaries[day, default: HistoryDaySummary(date: day)].log = log
        }
        for entry in foodEntries {
            let day = calendar.startOfDay(for: entry.date)
            summaries[day, default: HistoryDaySummary(date: day)].foodEntries.append(entry)
        }
        for entry in activityEntries {
            let day = calendar.startOfDay(for: entry.date)
            summaries[day, default: HistoryDaySummary(date: day)].activityEntries.append(entry)
        }
        for movement in bowelMovements {
            let day = calendar.startOfDay(for: movement.date)
            summaries[day, default: HistoryDaySummary(date: day)].bowelMovements.append(movement)
        }
        self.summaries = summaries
    }

    func getDaySummaries() -> [Date: HistoryDaySummary] {
        summaries
    }

    func loadDaySummaries() throws -> [Date: HistoryDaySummary] {
        guard shouldReadSucceed else {
            throw RepositoryError(
                operation: .read,
                resource: "history",
                diagnostic: "Injected mock read failure."
            )
        }
        return summaries
    }
}
