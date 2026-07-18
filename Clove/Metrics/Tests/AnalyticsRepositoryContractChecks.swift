import Foundation

enum AnalyticsRepositoryContractChecks {
    static func assertAllPass(file: StaticString = #fileID, line: UInt = #line) {
        let zone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let start = calendar.date(from: DateComponents(year: 2024, month: 2, day: 10))!
        let end = calendar.date(byAdding: .day, value: 2, to: start)!
        let interval = DateInterval(start: start, end: end)
        let loader = FixtureAnalyticsSourceLoader(logs: [
            DailyLog(id: 3, date: end, mood: 10),
            DailyLog(id: 2, date: start.addingTimeInterval(86_400 + 60), mood: 8),
            DailyLog(id: 1, date: start.addingTimeInterval(60), mood: 6),
            DailyLog(id: 0, date: start.addingTimeInterval(-60), mood: 1)
        ])
        let repository = DefaultAnalyticsRepository(
            sourceLoader: loader,
            calendar: calendar,
            timeZone: zone
        )

        do {
            let dataset = try repository.load(AnalyticsRequest(
                interval: interval,
                metricIDs: [MetricCatalog.mood.id]
            ))
            precondition(loader.loadedIntervals == [interval], "Repository did not use the explicit range", file: file, line: line)
            precondition(dataset.observations.count == 2, "Half-open range boundaries failed", file: file, line: line)
            precondition(
                dataset.observations.map(\.timestamp) == dataset.observations.map(\.timestamp).sorted(),
                "Repository output was not deterministic",
                file: file,
                line: line
            )
            precondition(dataset.coverage[MetricCatalog.mood.id]?.possibleDayCount == 2, file: file, line: line)
            precondition(dataset.diagnostics.databaseReadCount == 1, "Expected one batched database read", file: file, line: line)
            precondition(dataset.diagnostics.statementCount == 9, "Statement count changed with metric count", file: file, line: line)
        } catch {
            preconditionFailure("Unexpected analytics repository error: \(error)", file: file, line: line)
        }

        do {
            _ = try repository.load(AnalyticsRequest(
                interval: interval,
                metricIDs: ["unknown_metric"]
            ))
            preconditionFailure("Unknown metric error was swallowed", file: file, line: line)
        } catch AnalyticsRepositoryError.unknownMetricIDs {
            // Expected.
        } catch {
            preconditionFailure("Unexpected error for unknown metric: \(error)", file: file, line: line)
        }

        do {
            let failing = DefaultAnalyticsRepository(
                sourceLoader: FailingAnalyticsSourceLoader(),
                timeZone: zone
            )
            _ = try failing.load(AnalyticsRequest(interval: interval))
            preconditionFailure("Source error was converted to empty data", file: file, line: line)
        } catch FixtureAnalyticsError.expected {
            // Expected.
        } catch {
            preconditionFailure("Unexpected propagated error: \(error)", file: file, line: line)
        }
    }
}

private final class FixtureAnalyticsSourceLoader: AnalyticsSourceLoading {
    private let logs: [DailyLog]
    private(set) var loadedIntervals: [DateInterval] = []

    init(logs: [DailyLog]) {
        self.logs = logs
    }

    func load(in interval: DateInterval) throws -> AnalyticsSourceSnapshot {
        loadedIntervals.append(interval)
        return AnalyticsSourceSnapshot(
            logs: logs.filter { $0.date >= interval.start && $0.date < interval.end },
            foodEntries: [],
            activityEntries: [],
            bowelMovements: [],
            cycleEntries: [],
            trackedSymptoms: [],
            trackedMedications: [],
            dynamicIdentities: [],
            metricAliases: [],
            diagnostics: AnalyticsQueryDiagnostics(databaseReadCount: 1, statementCount: 9)
        )
    }
}

private enum FixtureAnalyticsError: Error {
    case expected
}

private struct FailingAnalyticsSourceLoader: AnalyticsSourceLoading {
    func load(in interval: DateInterval) throws -> AnalyticsSourceSnapshot {
        throw FixtureAnalyticsError.expected
    }
}
