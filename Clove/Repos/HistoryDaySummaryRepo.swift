import Foundation
import GRDB

struct HistoryDaySummary {
    let date: Date
    var log: DailyLog?
    var foodEntries: [FoodEntry] = []
    var activityEntries: [ActivityEntry] = []
    var bowelMovements: [BowelMovement] = []

    var hasMeals: Bool {
        !foodEntries.isEmpty || !(log?.meals.isEmpty ?? true)
    }

    var hasActivities: Bool {
        !activityEntries.isEmpty || !(log?.activities.isEmpty ?? true)
    }

    var hasAnyData: Bool {
        hasMeals || hasActivities || !bowelMovements.isEmpty || hasDailyLogData
    }

    private var hasDailyLogData: Bool {
        guard let log else { return false }
        return log.mood != nil
            || log.painLevel != nil
            || log.energyLevel != nil
            || (log.waterIntake ?? 0) > 0
            || !log.medicationsTaken.isEmpty
            || !log.medicationAdherence.isEmpty
            || !(log.notes?.isEmpty ?? true)
            || log.isFlareDay
            || log.weather != nil
            || !log.symptomRatings.isEmpty
    }
}

protocol HistoryDaySummaryRepositoryProtocol {
    func getDaySummaries() -> [Date: HistoryDaySummary]
}

final class HistoryDaySummaryRepo: HistoryDaySummaryRepositoryProtocol {
    static let shared = HistoryDaySummaryRepo(databaseManager: DatabaseManager.shared)

    private let databaseManager: DatabaseManaging
    private let calendar: Calendar

    init(databaseManager: DatabaseManaging, calendar: Calendar = .current) {
        self.databaseManager = databaseManager
        self.calendar = calendar
    }

    func getDaySummaries() -> [Date: HistoryDaySummary] {
        do {
            let source = try databaseManager.read { db in
                (
                    logs: try DailyLog.fetchAll(db),
                    food: try FoodEntry.fetchAll(db),
                    activities: try ActivityEntry.fetchAll(db),
                    bowelMovements: try BowelMovement.fetchAll(db)
                )
            }

            var summaries: [Date: HistoryDaySummary] = [:]
            for log in source.logs {
                let day = calendar.startOfDay(for: log.date)
                summaries[day, default: HistoryDaySummary(date: day)].log = log
            }
            for entry in source.food {
                let day = calendar.startOfDay(for: entry.date)
                summaries[day, default: HistoryDaySummary(date: day)].foodEntries.append(entry)
            }
            for entry in source.activities {
                let day = calendar.startOfDay(for: entry.date)
                summaries[day, default: HistoryDaySummary(date: day)].activityEntries.append(entry)
            }
            for movement in source.bowelMovements {
                let day = calendar.startOfDay(for: movement.date)
                summaries[day, default: HistoryDaySummary(date: day)].bowelMovements.append(movement)
            }
            return summaries
        } catch {
            print("Error loading History day summaries: \(error)")
            return [:]
        }
    }
}
