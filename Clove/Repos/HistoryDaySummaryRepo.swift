import Foundation
import GRDB

struct HistoryDaySummary {
    let date: Date
    var log: DailyLog?
    var foodEntries: [FoodEntry] = []
    var activityEntries: [ActivityEntry] = []
    var bowelMovements: [BowelMovement] = []
    var customMetrics: [CustomMetricRecord] = []

    var hasMeals: Bool {
        !foodEntries.isEmpty || !(log?.meals.isEmpty ?? true)
    }

    var hasActivities: Bool {
        !activityEntries.isEmpty || !(log?.activities.isEmpty ?? true)
    }

    var hasAnyData: Bool {
        hasMeals || hasActivities || !bowelMovements.isEmpty || !customMetrics.isEmpty || hasDailyLogData
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
    func loadDaySummaries() throws -> [Date: HistoryDaySummary]
    func getDaySummaries() -> [Date: HistoryDaySummary]
}

extension HistoryDaySummaryRepositoryProtocol {
    func loadDaySummaries() throws -> [Date: HistoryDaySummary] {
        getDaySummaries()
    }
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
            return try loadDaySummaries()
        } catch {
            print("Error loading History day summaries: \(error)")
            return [:]
        }
    }

    func loadDaySummaries() throws -> [Date: HistoryDaySummary] {
        do {
            let source = try databaseManager.read { db in
                (
                    logs: try DailyLog.fetchAll(db),
                    food: try FoodEntry.fetchAll(db),
                    activities: try ActivityEntry.fetchAll(db),
                    bowelMovements: try BowelMovement.fetchAll(db),
                    customDefinitions: try CustomMetricDefinition.fetchAll(db),
                    customValues: try CustomDailyValue.fetchAll(db)
                )
            }

            var summaries: [Date: HistoryDaySummary] = [:]
            for log in source.logs {
                let day = log.date(in: calendar)
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
            let definitions = Dictionary(uniqueKeysWithValues: source.customDefinitions.map { ($0.id, $0) })
            for value in source.customValues {
                guard let day = LocalDayKey.date(from: value.dayKey, calendar: calendar), let definition = definitions[value.metricID] else { continue }
                summaries[day, default: HistoryDaySummary(date: day)].customMetrics.append(CustomMetricRecord(definition: definition, value: value))
            }
            for key in Array(summaries.keys) {
                summaries[key]?.customMetrics.sort { $0.definition.displayOrder < $1.definition.displayOrder }
            }
            return summaries
        } catch {
            throw RepositoryError(operation: .read, resource: "history", underlyingError: error)
        }
    }
}
