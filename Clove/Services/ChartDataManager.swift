import Foundation
import GRDB

// MARK: - Data Models for Chart System

enum MetricType: String, CaseIterable, Identifiable {
    case mood
    case painLevel
    case energyLevel
    case flareDay
    case medicationAdherence
    case activityCount
    case mealCount
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .mood: return "Mood"
        case .painLevel: return "Pain Level"
        case .energyLevel: return "Energy Level"
        case .flareDay: return "Flare Days"
        case .medicationAdherence: return "Medication Adherence"
        case .activityCount: return "Activity Count"
        case .mealCount: return "Meal Count"
        }
    }
    
    var description: String {
        switch self {
        case .mood: return "1-10 scale tracking daily mood"
        case .painLevel: return "1-10 scale tracking pain intensity"
        case .energyLevel: return "1-10 scale tracking energy levels"
        case .flareDay: return "Frequency of flare-up days"
        case .medicationAdherence: return "Percentage of medications taken as prescribed"
        case .activityCount: return "Number of activities logged per day"
        case .mealCount: return "Number of meals logged per day"
        }
    }
    
    var icon: String {
        switch self {
        case .mood: return "😊"
        case .painLevel: return "🔥"
        case .energyLevel: return "⚡"
        case .flareDay: return "⚠️"
        case .medicationAdherence: return "💊"
        case .activityCount: return "🏃"
        case .mealCount: return "🍎"
        }
    }
}

enum MetricCategory: String, CaseIterable, Identifiable {
    case coreHealth
    case symptoms
    case medications
    case lifestyle
    case environmental
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .coreHealth: return "Core Health"
        case .symptoms: return "Symptoms"
        case .medications: return "Medications"
        case .lifestyle: return "Lifestyle"
        case .environmental: return "Environmental"
        }
    }
}


struct ChartDataPoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let value: Double
    let metricType: MetricType
    let metricName: String
    let category: MetricCategory
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(date)
        hasher.combine(value)
        hasher.combine(metricType)
        hasher.combine(metricName)
    }
    
    static func == (lhs: ChartDataPoint, rhs: ChartDataPoint) -> Bool {
        lhs.date == rhs.date &&
        lhs.value == rhs.value &&
        lhs.metricType == rhs.metricType &&
        lhs.metricName == rhs.metricName
    }
}

struct SymptomDataPoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let value: Double
    let symptomName: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(date)
        hasher.combine(value)
        hasher.combine(symptomName)
    }
    
    static func == (lhs: SymptomDataPoint, rhs: SymptomDataPoint) -> Bool {
        lhs.date == rhs.date &&
        lhs.value == rhs.value &&
        lhs.symptomName == rhs.symptomName
    }
}

struct ChartStatistics {
    let mean: Double
    let median: Double
    let min: Double
    let max: Double
    let count: Int
    let trend: TrendDirection
    let changePercentage: Double
    
    enum TrendDirection {
        case increasing, decreasing, stable
    }
}

// MARK: - Chart Data Manager

class ChartDataManager {
    static let shared = ChartDataManager()
    
    private let logsRepo = LogsRepo.shared
    private let symptomsRepo = SymptomsRepo.shared
    private var cachedData: [String: [ChartDataPoint]] = [:]
    private var cacheTimestamps: [String: Date] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
    // MARK: - Public API
    
    /// Get chart data for a specific metric and time period
    func getChartData(for metricType: MetricType, period: TimePeriod) -> [ChartDataPoint] {
        let cacheKey = "\(metricType.rawValue)_\(period.rawValue)"
        
        // Check cache
        if let cachedData = getCachedData(for: cacheKey) {
            return cachedData
        }
        
        let logs = getLogsForPeriod(period)
        let dataPoints = processMetricData(metricType: metricType, logs: logs)
        let aggregatedData = aggregateDataForPeriod(dataPoints, period: period)
        
        // Cache the result
        setCachedData(aggregatedData, for: cacheKey)
        
        return aggregatedData
    }
    
    /// Get chart data for a specific symptom and time period
    func getSymptomChartData(symptomName: String, period: TimePeriod) -> [SymptomDataPoint] {
        let cacheKey = "symptom_\(symptomName)_\(period.rawValue)"
        
        // For symptoms, we need to use a different cache structure
        if let cachedTimestamp = cacheTimestamps[cacheKey],
           Date().timeIntervalSince(cachedTimestamp) < cacheTimeout {
            // Return cached symptom data if available
            return getSymptomDataFromLogs(symptomName: symptomName, period: period)
        }
        
        let data = getSymptomDataFromLogs(symptomName: symptomName, period: period)
        cacheTimestamps[cacheKey] = Date()
        
        return data
    }
    
    /// Get all available core health metrics
    func getAvailableMetrics() -> [MetricType] {
        let logs = logsRepo.getLogs()
        var availableMetrics: [MetricType] = []
        
        // Check which metrics have data
        if logs.contains(where: { $0.mood != nil }) {
            availableMetrics.append(.mood)
        }
        if logs.contains(where: { $0.painLevel != nil }) {
            availableMetrics.append(.painLevel)
        }
        if logs.contains(where: { $0.energyLevel != nil }) {
            availableMetrics.append(.energyLevel)
        }
        if logs.contains(where: { $0.isFlareDay }) {
            availableMetrics.append(.flareDay)
        }
        if logs.contains(where: { !$0.medicationAdherence.isEmpty }) {
            availableMetrics.append(.medicationAdherence)
        }
        if logs.contains(where: { !$0.activities.isEmpty }) {
            availableMetrics.append(.activityCount)
        }
        if logs.contains(where: { !$0.meals.isEmpty }) {
            availableMetrics.append(.mealCount)
        }
        
        return availableMetrics
    }
    
    /// Get all available symptoms that have been tracked
    func getAvailableSymptoms() -> [String] {
        let trackedSymptoms = symptomsRepo.getTrackedSymptoms()
        let logs = logsRepo.getLogs()
        
        // Filter to only symptoms that have actual data
        return trackedSymptoms.compactMap { symptom in
            let hasData = logs.contains { log in
                log.symptomRatings.contains { $0.symptomName == symptom.name }
            }
            return hasData ? symptom.name : nil
        }
    }
    
    /// Calculate statistics for a dataset
    func calculateStatistics(for data: [ChartDataPoint]) -> ChartStatistics {
        guard !data.isEmpty else {
            return ChartStatistics(mean: 0, median: 0, min: 0, max: 0, count: 0, trend: .stable, changePercentage: 0)
        }
        
        let values = data.map { $0.value }
        let sortedValues = values.sorted()
        
        let mean = values.reduce(0, +) / Double(values.count)
        let median = sortedValues.count % 2 == 0 ?
            (sortedValues[sortedValues.count / 2 - 1] + sortedValues[sortedValues.count / 2]) / 2 :
            sortedValues[sortedValues.count / 2]
        let min = sortedValues.first ?? 0
        let max = sortedValues.last ?? 0
        
        // Calculate trend
        let trend = calculateTrend(for: data)
        let changePercentage = calculateChangePercentage(for: data)
        
        return ChartStatistics(
            mean: mean,
            median: median,
            min: min,
            max: max,
            count: data.count,
            trend: trend,
            changePercentage: changePercentage
        )
    }
    
    /// Get data point count for a metric
    func getDataPointCount(for metricType: MetricType) -> Int {
        let logs = logsRepo.getLogs()
        
        switch metricType {
        case .mood:
            return logs.compactMap { $0.mood }.count
        case .painLevel:
            return logs.compactMap { $0.painLevel }.count
        case .energyLevel:
            return logs.compactMap { $0.energyLevel }.count
        case .flareDay:
            return logs.filter { $0.isFlareDay }.count
        case .medicationAdherence:
            return logs.filter { !$0.medicationAdherence.isEmpty }.count
        case .activityCount:
            return logs.filter { !$0.activities.isEmpty }.count
        case .mealCount:
            return logs.filter { !$0.meals.isEmpty }.count
        }
    }
    
    /// Get data point count for a symptom
    func getSymptomDataPointCount(symptomName: String) -> Int {
        let logs = logsRepo.getLogs()
        return logs.filter { log in
            log.symptomRatings.contains { $0.symptomName == symptomName }
        }.count
    }
    
    /// Clear all cached data
    func clearCache() {
        cachedData.removeAll()
        cacheTimestamps.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func getLogsForPeriod(_ period: TimePeriod) -> [DailyLog] {
        let logs = logsRepo.getLogs()
        
        guard period != .allTime else {
            return logs.sorted { $0.date < $1.date }
        }
        
        guard let dateRange = period.dateRange else {
            return logs.sorted { $0.date < $1.date }
        }
        
        return logs.filter { log in
            dateRange.contains(log.date)
        }.sorted { $0.date < $1.date }
    }
    
    private func processMetricData(metricType: MetricType, logs: [DailyLog]) -> [ChartDataPoint] {
        var dataPoints: [ChartDataPoint] = []
        
        for log in logs {
            let value: Double?
            let category: MetricCategory
            
            switch metricType {
            case .mood:
                value = log.mood.map { Double($0) }
                category = .coreHealth
            case .painLevel:
                value = log.painLevel.map { Double($0) }
                category = .coreHealth
            case .energyLevel:
                value = log.energyLevel.map { Double($0) }
                category = .coreHealth
            case .flareDay:
                value = log.isFlareDay ? 1.0 : 0.0
                category = .environmental
            case .medicationAdherence:
                value = calculateMedicationAdherenceRate(log.medicationAdherence)
                category = .medications
            case .activityCount:
                value = Double(log.activities.count)
                category = .lifestyle
            case .mealCount:
                value = Double(log.meals.count)
                category = .lifestyle
            }
            
            if let value = value {
                let dataPoint = ChartDataPoint(
                    date: log.date,
                    value: value,
                    metricType: metricType,
                    metricName: metricType.displayName,
                    category: category
                )
                dataPoints.append(dataPoint)
            }
        }
        
        return dataPoints
    }
    
    private func getSymptomDataFromLogs(symptomName: String, period: TimePeriod) -> [SymptomDataPoint] {
        let logs = getLogsForPeriod(period)
        var dataPoints: [SymptomDataPoint] = []
        
        for log in logs {
            if let symptomRating = log.symptomRatings.first(where: { $0.symptomName == symptomName }) {
                let dataPoint = SymptomDataPoint(
                    date: log.date,
                    value: Double(symptomRating.rating),
                    symptomName: symptomName
                )
                dataPoints.append(dataPoint)
            }
        }
        
        return dataPoints
    }
    
    private func calculateMedicationAdherenceRate(_ adherence: [MedicationAdherence]) -> Double? {
        guard !adherence.isEmpty else { return nil }
        
        let takenCount = adherence.filter { $0.wasTaken }.count
        return (Double(takenCount) / Double(adherence.count)) * 100.0
    }
    
    private func aggregateDataForPeriod(_ data: [ChartDataPoint], period: TimePeriod) -> [ChartDataPoint] {
        // Use the aggregation level from TimePeriodManager
        let aggregationLevel = period.aggregationLevel
        
        guard aggregationLevel != .daily else {
            return data // No aggregation needed for daily data
        }
        
        let calendar = Calendar.current
        var aggregatedData: [ChartDataPoint] = []
        
        let groupingComponent: Calendar.Component = aggregationLevel == .monthly ? .month : .weekOfYear
        
        let grouped = Dictionary(grouping: data) { dataPoint in
            calendar.component(groupingComponent, from: dataPoint.date)
        }
        
        for (_, points) in grouped {
            guard !points.isEmpty else { continue }
            
            let averageValue = points.map { $0.value }.reduce(0, +) / Double(points.count)
            let representativeDate = points.sorted { $0.date < $1.date }.first?.date ?? Date()
            
            if let firstPoint = points.first {
                let aggregatedPoint = ChartDataPoint(
                    date: representativeDate,
                    value: averageValue,
                    metricType: firstPoint.metricType,
                    metricName: firstPoint.metricName,
                    category: firstPoint.category
                )
                aggregatedData.append(aggregatedPoint)
            }
        }
        
        return aggregatedData.sorted { $0.date < $1.date }
    }
    
    private func calculateTrend(for data: [ChartDataPoint]) -> ChartStatistics.TrendDirection {
        guard data.count >= 2 else { return .stable }
        
        let sortedData = data.sorted { $0.date < $1.date }
        let firstHalf = sortedData.prefix(sortedData.count / 2)
        let secondHalf = sortedData.suffix(sortedData.count / 2)
        
        let firstAverage = firstHalf.map { $0.value }.reduce(0, +) / Double(firstHalf.count)
        let secondAverage = secondHalf.map { $0.value }.reduce(0, +) / Double(secondHalf.count)
        
        let difference = secondAverage - firstAverage
        let threshold = firstAverage * 0.05 // 5% threshold
        
        if difference > threshold {
            return .increasing
        } else if difference < -threshold {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    private func calculateChangePercentage(for data: [ChartDataPoint]) -> Double {
        guard data.count >= 2 else { return 0 }
        
        let sortedData = data.sorted { $0.date < $1.date }
        guard let firstValue = sortedData.first?.value,
              let lastValue = sortedData.last?.value,
              firstValue != 0 else { return 0 }
        
        return ((lastValue - firstValue) / firstValue) * 100
    }
    
    private func getCachedData(for key: String) -> [ChartDataPoint]? {
        guard let timestamp = cacheTimestamps[key],
              Date().timeIntervalSince(timestamp) < cacheTimeout,
              let data = cachedData[key] else {
            return nil
        }
        return data
    }
    
    private func setCachedData(_ data: [ChartDataPoint], for key: String) {
        cachedData[key] = data
        cacheTimestamps[key] = Date()
    }
}

// MARK: - Extensions

extension MetricType {
    var category: MetricCategory {
        switch self {
        case .mood, .painLevel, .energyLevel:
            return .coreHealth
        case .medicationAdherence:
            return .medications
        case .activityCount, .mealCount:
            return .lifestyle
        case .flareDay:
            return .environmental
        }
    }
}
