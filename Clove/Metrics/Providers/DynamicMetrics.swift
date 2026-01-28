import Foundation
import SwiftUI

// MARK: - Symptom Metric Provider

struct SymptomMetricProvider: MetricProvider {
    let symptomName: String
    let isActive: Bool
    
    var id: String { "symptom_\(symptomName.lowercased().replacingOccurrences(of: " ", with: "_"))" }
    var displayName: String { symptomName }
    var description: String { "Tracking \(symptomName.lowercased()) severity" }
    let icon = "🩹"
    let category: MetricCategory = .symptoms
    var dataType: MetricDataType = .continuous(range: 0...10)
    var chartType: MetricChartType = .line
    let valueRange: ClosedRange<Double>? = 0...10
    
    private let dataLoader = OptimizedDataLoader.shared
    
    init(symptomName: String, isActive: Bool = true, isBinary: Bool = false) {
        self.symptomName = symptomName
        self.isActive = isActive
        self.dataType = isBinary ? .binary : .continuous(range: 0...10)
        self.chartType = isBinary ? .scatter : .line
    }
    
    func getDataPoints(for period: TimePeriod) async -> [MetricDataPoint] {
        let logs = await dataLoader.filterSessionLogs(for: period)
        
        return logs.compactMap { log in
            guard let symptomRating = log.symptomRatings.first(where: { $0.symptomName == symptomName }) else { return nil }
            
            return MetricDataPoint(
                date: log.date,
                value: Double(symptomRating.rating),
                rawValue: symptomRating,
                metricId: id
            )
        }
    }
    
    func getDataPointCount(for period: TimePeriod) async -> Int {
        return await dataLoader.getDataPointCount(for: period) { log in
            log.symptomRatings.contains { $0.symptomName == symptomName }
        }
    }
    
    func formatValue(_ value: Double) -> String {
        switch dataType {
        case .binary:
            return value < 5 ? "❌" : "✅"
        default:
            return String(Int(value.rounded()))
        }
    }
}

// MARK: - Medication Metric Provider

struct MedicationMetricProvider: MetricProvider {
    let medicationName: String
    
    var id: String { "medication_\(medicationName.lowercased().replacingOccurrences(of: " ", with: "_"))" }
    var displayName: String { medicationName }
    var description: String { "Days when \(medicationName) was taken" }
    let icon = "💊"
    let category: MetricCategory = .medications
    let dataType: MetricDataType = .binary
    let chartType: MetricChartType = .line
    let valueRange: ClosedRange<Double>? = 0...1
    
    private let dataLoader = OptimizedDataLoader.shared
    
    init(medicationName: String) {
        self.medicationName = medicationName
    }
    
    func getDataPoints(for period: TimePeriod) async -> [MetricDataPoint] {
        let logs = await dataLoader.filterSessionLogs(for: period)
        
        return logs.map { log in
            let wasTaken = log.medicationsTaken.contains(medicationName)
            return MetricDataPoint(
                date: log.date,
                value: wasTaken ? 1.0 : 0.0,
                rawValue: wasTaken,
                metricId: id
            )
        }
    }
    
    func getDataPointCount(for period: TimePeriod) async -> Int {
        return await dataLoader.getDataPointCount(for: period) { log in
            log.medicationsTaken.contains(medicationName)
        }
    }
    
    func formatValue(_ value: Double) -> String {
        return value == 1.0 ? "✅" : "❌"
    }
    
    var chartConfiguration: MetricChartConfiguration {
        MetricChartConfiguration(
            chartType: .line,
            primaryColor: CloveColors.blue,
            showGradient: false,
            lineWidth: 3.0,
            showDataPoints: true,
            enableInteraction: true
        )
    }
}

// MARK: - Activity Metric Provider

struct ActivityMetricProvider: MetricProvider {
    let activityName: String

    var id: String { "activity_\(activityName.lowercased().replacingOccurrences(of: " ", with: "_"))" }
    var displayName: String { activityName }
    var description: String { "Days when \(activityName.lowercased()) was done" }
    let icon = "🏃"
    let category: MetricCategory = .activities
    let dataType: MetricDataType = .binary
    let chartType: MetricChartType = .line
    let valueRange: ClosedRange<Double>? = 0...1

    private let dataLoader = OptimizedDataLoader.shared
    private let activityRepo = ActivityEntryRepo.shared

    init(activityName: String) {
        self.activityName = activityName
    }

    func getDataPoints(for period: TimePeriod) async -> [MetricDataPoint] {
        let entries = activityRepo.getEntries(for: period)
        let calendar = Calendar.current

        // Get all unique days with this activity
        var dayData: [Date: Bool] = [:]
        for entry in entries {
            if entry.name.lowercased() == activityName.lowercased() {
                let dayStart = calendar.startOfDay(for: entry.date)
                dayData[dayStart] = true
            }
        }

        // Create data points for each unique day
        return dayData.map { (date, wasDone) in
            MetricDataPoint(
                date: date,
                value: wasDone ? 1.0 : 0.0,
                rawValue: wasDone,
                metricId: id
            )
        }.sorted { $0.date < $1.date }
    }

    func getDataPointCount(for period: TimePeriod) async -> Int {
        let entries = activityRepo.getEntries(for: period)
        let calendar = Calendar.current

        // Count unique days with this activity
        var uniqueDays = Set<Date>()
        for entry in entries {
            if entry.name.lowercased() == activityName.lowercased() {
                let dayStart = calendar.startOfDay(for: entry.date)
                uniqueDays.insert(dayStart)
            }
        }

        return uniqueDays.count
    }

    func formatValue(_ value: Double) -> String {
        return value == 1.0 ? "✅" : "❌"
    }

    var chartConfiguration: MetricChartConfiguration {
        MetricChartConfiguration(
            chartType: .line,
            primaryColor: CloveColors.green,
            showGradient: false,
            lineWidth: 3.0,
            showDataPoints: true,
            enableInteraction: true
        )
    }
}

// MARK: - Meal Metric Provider

struct MealMetricProvider: MetricProvider {
    let mealName: String

    var id: String { "meal_\(mealName.lowercased().replacingOccurrences(of: " ", with: "_"))" }
    var displayName: String { mealName }
    var description: String { "Days when \(mealName.lowercased()) was eaten" }
    let icon = "🍽️"
    let category: MetricCategory = .meals
    let dataType: MetricDataType = .binary
    let chartType: MetricChartType = .line
    let valueRange: ClosedRange<Double>? = 0...1

    private let dataLoader = OptimizedDataLoader.shared
    private let foodRepo = FoodEntryRepo.shared

    init(mealName: String) {
        self.mealName = mealName
    }

    func getDataPoints(for period: TimePeriod) async -> [MetricDataPoint] {
        let entries = foodRepo.getEntries(for: period)
        let calendar = Calendar.current

        // Get all unique days with this meal
        var dayData: [Date: Bool] = [:]
        for entry in entries {
            if entry.name.lowercased() == mealName.lowercased() {
                let dayStart = calendar.startOfDay(for: entry.date)
                dayData[dayStart] = true
            }
        }

        // Create data points for each unique day
        return dayData.map { (date, wasEaten) in
            MetricDataPoint(
                date: date,
                value: wasEaten ? 1.0 : 0.0,
                rawValue: wasEaten,
                metricId: id
            )
        }.sorted { $0.date < $1.date }
    }

    func getDataPointCount(for period: TimePeriod) async -> Int {
        let entries = foodRepo.getEntries(for: period)
        let calendar = Calendar.current

        // Count unique days with this meal
        var uniqueDays = Set<Date>()
        for entry in entries {
            if entry.name.lowercased() == mealName.lowercased() {
                let dayStart = calendar.startOfDay(for: entry.date)
                uniqueDays.insert(dayStart)
            }
        }

        return uniqueDays.count
    }

    func formatValue(_ value: Double) -> String {
        return value == 1.0 ? "✅" : "❌"
    }

    var chartConfiguration: MetricChartConfiguration {
        MetricChartConfiguration(
            chartType: .line,
            primaryColor: CloveColors.orange,
            showGradient: false,
            lineWidth: 3.0,
            showDataPoints: true,
            enableInteraction: true
        )
    }
}

// MARK: - Weather Metric Provider

struct WeatherMetricProvider: MetricProvider {
    let id = "weather"
    let displayName = "Weather"
    let description = "Daily weather conditions (clear to stormy scale)"
    let icon = "🌤️"
    let category: MetricCategory = .environmental
    let dataType: MetricDataType = .categorical(values: ["Stormy", "Rainy", "Gloomy", "Cloudy", "Snow", "Sunny"])
    let chartType: MetricChartType = .line
    let valueRange: ClosedRange<Double>? = 1...6
    
    private let dataLoader = OptimizedDataLoader.shared
    
    func getDataPoints(for period: TimePeriod) async -> [MetricDataPoint] {
        let logs = await dataLoader.filterSessionLogs(for: period)
        
        return logs.compactMap { log in
            guard let weather = log.weather else { return nil }
            
            return MetricDataPoint(
                date: log.date,
                value: convertWeatherToNumeric(weather),
                rawValue: weather,
                metricId: id
            )
        }
    }
    
    func getDataPointCount(for period: TimePeriod) async -> Int {
        return await dataLoader.getDataPointCount(for: period) { log in
            log.weather != nil
        }
    }
    
    func formatValue(_ value: Double) -> String {
        return convertNumericToWeather(value)
    }
    
    var chartConfiguration: MetricChartConfiguration {
        MetricChartConfiguration(
            chartType: .line,
            primaryColor: CloveColors.blue,
            showGradient: true,
            lineWidth: 3.0,
            showDataPoints: true,
            enableInteraction: true
        )
    }
    
    /// Convert weather string to numerical value for correlation analysis
    /// Scale: 1 (Stormy/harsh) to 6 (Sunny/clear)
    private func convertWeatherToNumeric(_ weather: String) -> Double {
        switch weather.lowercased() {
        case "stormy": return 1.0
        case "rainy": return 2.0
        case "gloomy": return 3.0
        case "cloudy": return 4.0
        case "snow": return 5.0
        case "sunny": return 6.0
        default: return 3.5 // Neutral/unknown weather
        }
    }
    
    /// Convert numerical weather value back to readable string
    private func convertNumericToWeather(_ numericValue: Double) -> String {
        switch numericValue {
        case 1.0: return "Stormy"
        case 2.0: return "Rainy"
        case 3.0: return "Gloomy"
        case 4.0: return "Cloudy"
        case 5.0: return "Snow"
        case 6.0: return "Sunny"
        default: return "Mixed"
        }
    }
}

// MARK: - Count-based Metrics

struct ActivityCountMetricProvider: MetricProvider {
    let id = "activity_count"
    let displayName = "Activity Count"
    let description = "Number of activities logged per day"
    let icon = "🏃"
    let category: MetricCategory = .activities
    let dataType: MetricDataType = .count
    let chartType: MetricChartType = .bar
    let valueRange: ClosedRange<Double>? = nil

    private let dataLoader = OptimizedDataLoader.shared
    private let activityRepo = ActivityEntryRepo.shared

    func getDataPoints(for period: TimePeriod) async -> [MetricDataPoint] {
        let entries = activityRepo.getEntries(for: period)
        let calendar = Calendar.current

        // Count entries by day
        var countsByDay: [Date: Int] = [:]
        for entry in entries {
            let dayStart = calendar.startOfDay(for: entry.date)
            countsByDay[dayStart, default: 0] += 1
        }

        // Create data points for each unique day with activities
        return countsByDay.map { (date, count) in
            MetricDataPoint(
                date: date,
                value: Double(count),
                rawValue: count,
                metricId: id
            )
        }.sorted { $0.date < $1.date }
    }

    func getDataPointCount(for period: TimePeriod) async -> Int {
        let entries = activityRepo.getEntries(for: period)
        let calendar = Calendar.current

        // Count unique days with activities
        var uniqueDays = Set<Date>()
        for entry in entries {
            let dayStart = calendar.startOfDay(for: entry.date)
            uniqueDays.insert(dayStart)
        }

        return uniqueDays.count
    }

    func formatValue(_ value: Double) -> String {
        return String(Int(value))
    }
}

struct MealCountMetricProvider: MetricProvider {
    let id = "meal_count"
    let displayName = "Meal Count"
    let description = "Number of meals logged per day"
    let icon = "🍎"
    let category: MetricCategory = .meals
    let dataType: MetricDataType = .count
    let chartType: MetricChartType = .bar
    let valueRange: ClosedRange<Double>? = nil

    private let dataLoader = OptimizedDataLoader.shared
    private let foodRepo = FoodEntryRepo.shared

    func getDataPoints(for period: TimePeriod) async -> [MetricDataPoint] {
        let entries = foodRepo.getEntries(for: period)
        let calendar = Calendar.current

        // Count entries by day
        var countsByDay: [Date: Int] = [:]
        for entry in entries {
            let dayStart = calendar.startOfDay(for: entry.date)
            countsByDay[dayStart, default: 0] += 1
        }

        // Create data points for each unique day with meals
        return countsByDay.map { (date, count) in
            MetricDataPoint(
                date: date,
                value: Double(count),
                rawValue: count,
                metricId: id
            )
        }.sorted { $0.date < $1.date }
    }

    func getDataPointCount(for period: TimePeriod) async -> Int {
        let entries = foodRepo.getEntries(for: period)
        let calendar = Calendar.current

        // Count unique days with meals
        var uniqueDays = Set<Date>()
        for entry in entries {
            let dayStart = calendar.startOfDay(for: entry.date)
            uniqueDays.insert(dayStart)
        }

        return uniqueDays.count
    }

    func formatValue(_ value: Double) -> String {
        return String(Int(value))
    }
}
