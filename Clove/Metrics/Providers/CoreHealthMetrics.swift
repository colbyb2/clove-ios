import Foundation
import SwiftUI

// MARK: - Mood Metric Provider

struct MoodMetricProvider: MetricProvider {
    let id = "mood"
    let displayName = "Mood"
    let description = "1-10 scale tracking daily mood"
    let icon = "😊"
    let category: MetricCategory = .coreHealth
    let dataType: MetricDataType = .continuous(range: 0...10)
    let chartType: MetricChartType = .line
    let valueRange: ClosedRange<Double>? = 0...10
    
    private let dataLoader = OptimizedDataLoader.shared
    
    func getDataPoints(for period: TimePeriod) async -> [MetricDataPoint] {
        let logs = await dataLoader.filterSessionLogs(for: period)
        
        return logs.compactMap { log in
            guard let mood = log.mood else { return nil }
            return MetricDataPoint(
                date: log.date,
                value: Double(mood),
                rawValue: mood,
                metricId: id
            )
        }
    }
    
    func getDataPointCount(for period: TimePeriod) async -> Int {
        return await dataLoader.getDataPointCount(for: period) { log in
            log.mood != nil
        }
    }
    
    func formatValue(_ value: Double) -> String {
        return String(Int(value.rounded()))
    }
}

// MARK: - Pain Level Metric Provider

struct PainLevelMetricProvider: MetricProvider {
    let id = "pain_level"
    let displayName = "Pain Level"
    let description = "1-10 scale tracking pain intensity"
    let icon = "🔥"
    let category: MetricCategory = .coreHealth
    let dataType: MetricDataType = .continuous(range: 0...10)
    let chartType: MetricChartType = .line
    let valueRange: ClosedRange<Double>? = 0...10
    
    private let dataLoader = OptimizedDataLoader.shared
    
    func getDataPoints(for period: TimePeriod) async -> [MetricDataPoint] {
        let logs = await dataLoader.filterSessionLogs(for: period)
        
        return logs.compactMap { log in
            guard let painLevel = log.painLevel else { return nil }
            return MetricDataPoint(
                date: log.date,
                value: Double(painLevel),
                rawValue: painLevel,
                metricId: id
            )
        }
    }
    
    func getDataPointCount(for period: TimePeriod) async -> Int {
        return await dataLoader.getDataPointCount(for: period) { log in
            log.painLevel != nil
        }
    }
    
    func formatValue(_ value: Double) -> String {
        return String(Int(value.rounded()))
    }
}

// MARK: - Energy Level Metric Provider

struct EnergyLevelMetricProvider: MetricProvider {
    let id = "energy_level"
    let displayName = "Energy Level"
    let description = "1-10 scale tracking energy levels"
    let icon = "⚡"
    let category: MetricCategory = .coreHealth
    let dataType: MetricDataType = .continuous(range: 0...10)
    let chartType: MetricChartType = .line
    let valueRange: ClosedRange<Double>? = 0...10
    
    private let dataLoader = OptimizedDataLoader.shared
    
    func getDataPoints(for period: TimePeriod) async -> [MetricDataPoint] {
        let logs = await dataLoader.filterSessionLogs(for: period)
        
        return logs.compactMap { log in
            guard let energyLevel = log.energyLevel else { return nil }
            return MetricDataPoint(
                date: log.date,
                value: Double(energyLevel),
                rawValue: energyLevel,
                metricId: id
            )
        }
    }
    
    func getDataPointCount(for period: TimePeriod) async -> Int {
        return await dataLoader.getDataPointCount(for: period) { log in
            log.energyLevel != nil
        }
    }
    
    func formatValue(_ value: Double) -> String {
        return String(Int(value.rounded()))
    }
}

// MARK: - Flare Day Metric Provider

struct FlareDayMetricProvider: MetricProvider {
    let id = "flare_day"
    let displayName = "Flare Days"
    let description = "Frequency of flare-up days"
    let icon = "⚠️"
    let category: MetricCategory = .coreHealth
    let dataType: MetricDataType = .binary
    let chartType: MetricChartType = .line
    let valueRange: ClosedRange<Double>? = 0...1
    
    private let dataLoader = OptimizedDataLoader.shared
    
    func getDataPoints(for period: TimePeriod) async -> [MetricDataPoint] {
        let logs = await dataLoader.filterSessionLogs(for: period)
        
        return logs.map { log in
            MetricDataPoint(
                date: log.date,
                value: log.isFlareDay ? 1.0 : 0.0,
                rawValue: log.isFlareDay,
                metricId: id
            )
        }
    }
    
    func getDataPointCount(for period: TimePeriod) async -> Int {
        // For flare days, we count all days (since we track both flare and non-flare days)
        let logs = await dataLoader.filterSessionLogs(for: period)
        return logs.count
    }
    
    func formatValue(_ value: Double) -> String {
        return value == 1.0 ? "✅" : "❌"
    }
    
    var chartConfiguration: MetricChartConfiguration {
        MetricChartConfiguration(
            chartType: .line,
            primaryColor: CloveColors.red,
            showGradient: false,
            lineWidth: 3.0,
            showDataPoints: true,
            enableInteraction: true
        )
    }
}

// MARK: - Medication Adherence Metric Provider

struct MedicationAdherenceMetricProvider: MetricProvider {
    let id = "medication_adherence"
    let displayName = "Medication Adherence"
    let description = "Percentage of medications taken as prescribed"
    let icon = "💊"
    let category: MetricCategory = .medications
    let dataType: MetricDataType = .percentage
    let chartType: MetricChartType = .area
    let valueRange: ClosedRange<Double>? = 0...100
    
    private let dataLoader = OptimizedDataLoader.shared
    
    func getDataPoints(for period: TimePeriod) async -> [MetricDataPoint] {
        let logs = await dataLoader.filterSessionLogs(for: period)
        
        return logs.compactMap { log in
            let adherenceRate = calculateMedicationAdherenceRate(log.medicationAdherence)
            guard let rate = adherenceRate else { return nil }
            
            return MetricDataPoint(
                date: log.date,
                value: rate,
                rawValue: log.medicationAdherence,
                metricId: id
            )
        }
    }
    
    func getDataPointCount(for period: TimePeriod) async -> Int {
        return await dataLoader.getDataPointCount(for: period) { log in
            !log.medicationAdherence.isEmpty
        }
    }
    
    func formatValue(_ value: Double) -> String {
        return String(format: "%.0f%%", value)
    }
    
    var chartConfiguration: MetricChartConfiguration {
        MetricChartConfiguration(
            chartType: .area,
            primaryColor: CloveColors.blue,
            showGradient: true,
            lineWidth: 2.5,
            showDataPoints: true,
            enableInteraction: true
        )
    }
    
    private func calculateMedicationAdherenceRate(_ adherence: [MedicationAdherence]) -> Double? {
        // Filter out as-needed medications from adherence calculation
        let regularMedications = adherence.filter { !$0.isAsNeeded }
        guard !regularMedications.isEmpty else { return nil }
        
        let takenCount = regularMedications.filter { $0.wasTaken }.count
        return (Double(takenCount) / Double(regularMedications.count)) * 100.0
    }
}

struct BowelMovementMetricProvider: MetricProvider {
    let id: String = "bowelMovements"

    let displayName: String = "Bowel Movements"

    let description: String = "Daily bowel movements."

    let icon: String = "💩"

    var category: MetricCategory = .coreHealth

    var dataType: MetricDataType = .count

    var chartType: MetricChartType = .stackedBar

    var valueRange: ClosedRange<Double>? = 1...7

    func getDataPoints(for period: TimePeriod) async -> [MetricDataPoint] {
        let data: [MetricDataPoint] = BowelMovementRepo.shared.getBowelMovements(for: period)
            .map { bm in
                return MetricDataPoint(date: bm.date, value: bm.type, metricId: self.id)
            }
        return data
    }

    func formatValue(_ value: Double) -> String {
        return "Type \(Int(value.rounded()))"
    }

    func getDataPointCount(for period: TimePeriod) async -> Int {
        return BowelMovementRepo.shared.getBowelMovements(for: period).count
    }

}

// MARK: - Flow Level Metric Provider

struct FlowLevelMetricProvider: MetricProvider {
    let id = "flow_level"
    let displayName = "Flow Level"
    let description = "Period flow intensity"
    let icon = "🩸"
    let category: MetricCategory = .coreHealth
    let dataType: MetricDataType = .continuous(range: 0...5)
    let chartType: MetricChartType = .line
    let valueRange: ClosedRange<Double>? = 0...5

    func getDataPoints(for period: TimePeriod) async -> [MetricDataPoint] {
        let cycles = CycleRepo.shared.getCycles(for: period)

        return cycles.map { cycle in
            MetricDataPoint(
                date: cycle.date,
                value: cycle.flow.numericValue,
                rawValue: cycle.flow,
                metricId: id
            )
        }
    }

    func getDataPointCount(for period: TimePeriod) async -> Int {
        return CycleRepo.shared.getCycles(for: period).count
    }

    func formatValue(_ value: Double) -> String {
        switch value {
        case 0:
            return "None"
        case 1:
            return "Spotting"
        case 2:
            return "Light"
        case 3:
            return "Medium"
        case 4:
            return "Heavy"
        case 5:
            return "Very Heavy"
        default:
            return String(Int(value.rounded()))
        }
    }

    var chartConfiguration: MetricChartConfiguration {
        MetricChartConfiguration(
            chartType: .line,
            primaryColor: CloveColors.red,
            showGradient: true,
            lineWidth: 2.5,
            showDataPoints: true,
            enableInteraction: true
        )
    }
}
