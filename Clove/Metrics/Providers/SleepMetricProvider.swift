import Foundation

struct SleepMetricProvider: MetricProvider {
    let id = "sleep_duration"
    let displayName = "Sleep Duration"
    let description = "Time between bedtime and waking"
    let icon = "bed.double.fill"
    let category: MetricCategory = .coreHealth
    let dataType: MetricDataType = .custom
    let chartType: MetricChartType = .line
    let valueRange: ClosedRange<Double>? = nil

    func getDataPoints(for period: TimePeriod) async -> [MetricDataPoint] {
        let logs = await OptimizedDataLoader.shared.filterSessionLogs(for: period)
        return logs.compactMap { log in
            guard let sleep = log.sleep, (try? sleep.validate(dayKey: log.dayKey)) != nil else { return nil }
            return MetricDataPoint(date: log.date(in: Calendar.current), value: Double(sleep.durationMinutes), metricId: id)
        }
    }
    func getDataPointCount(for period: TimePeriod) async -> Int { await getDataPoints(for: period).count }
    func formatValue(_ value: Double) -> String { SleepPeriod.format(minutes: Int(value.rounded())) }
}
