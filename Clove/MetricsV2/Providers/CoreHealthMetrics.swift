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
