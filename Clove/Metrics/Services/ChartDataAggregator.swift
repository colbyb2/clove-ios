import Foundation

// MARK: - Data Aggregation Types

enum AggregationMethod: Sendable {
    case average        // For continuous data (mood, pain, energy)
    case sum           // For count data (activities, meals)
    case frequency     // For binary data (percentage of days with condition)
    case mode          // For categorical data (most common value)
    case latest        // For latest value in period
}

struct AggregationConfig: Sendable {
    let maxDataPoints: Int
    let method: AggregationMethod
    let preserveZeros: Bool // Whether to include periods with no data as zero
    
    static let `default` = AggregationConfig(
        maxDataPoints: 50,
        method: .average,
        preserveZeros: false
    )
}

struct AggregatedDataInfo: Sendable {
    let originalCount: Int
    let aggregatedCount: Int
    let aggregationLevel: AggregationLevel
    let method: AggregationMethod
    
    var wasAggregated: Bool { aggregatedCount < originalCount }
    var reductionPercentage: Double {
        guard originalCount > 0 else { return 0 }
        return Double(originalCount - aggregatedCount) / Double(originalCount) * 100
    }
}

// MARK: - Chart Data Aggregator

/// Service responsible for intelligently aggregating chart data to prevent overcrowding
class ChartDataAggregator {
    static let shared = ChartDataAggregator()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Intelligently aggregate data points based on time period and data density
    func aggregateData(
        _ data: [MetricDataPoint],
        for period: TimePeriod,
        config: AggregationConfig = .default
    ) -> (data: [MetricDataPoint], info: AggregatedDataInfo) {
        
        guard !data.isEmpty else {
            return (data: [], info: AggregatedDataInfo(
                originalCount: 0,
                aggregatedCount: 0,
                aggregationLevel: .daily,
                method: config.method
            ))
        }
        
        let sortedData = data.sorted { $0.date < $1.date }
        let aggregationLevel = determineAggregationLevel(
            dataCount: sortedData.count,
            period: period,
            maxPoints: config.maxDataPoints
        )
        
        let aggregatedData: [MetricDataPoint]
        
        switch aggregationLevel {
        case .daily:
            // No aggregation needed
            aggregatedData = sortedData
        case .weekly:
            aggregatedData = aggregateByPeriod(sortedData, level: .weekly, method: config.method, preserveZeros: config.preserveZeros)
        case .monthly:
            aggregatedData = aggregateByPeriod(sortedData, level: .monthly, method: config.method, preserveZeros: config.preserveZeros)
        }
        
        let info = AggregatedDataInfo(
            originalCount: sortedData.count,
            aggregatedCount: aggregatedData.count,
            aggregationLevel: aggregationLevel,
            method: config.method
        )
        
        return (data: aggregatedData, info: info)
    }
    
    /// Aggregate data with custom time intervals
    func aggregateByCustomInterval(
        _ data: [MetricDataPoint],
        intervalDays: Int,
        method: AggregationMethod
    ) -> [MetricDataPoint] {
        guard !data.isEmpty, intervalDays > 0 else { return data }
        
        let sortedData = data.sorted { $0.date < $1.date }
        let calendar = Calendar.current
        
        var aggregatedData: [MetricDataPoint] = []
        var currentGroupStart = sortedData.first!.date
        var currentGroup: [MetricDataPoint] = []
        
        for dataPoint in sortedData {
            let daysDiff = calendar.dateComponents([.day], from: currentGroupStart, to: dataPoint.date).day ?? 0
            
            if daysDiff < intervalDays {
                currentGroup.append(dataPoint)
            } else {
                // Process current group
                if let aggregatedPoint = aggregateGroup(currentGroup, method: method, groupDate: currentGroupStart) {
                    aggregatedData.append(aggregatedPoint)
                }
                
                // Start new group
                currentGroupStart = dataPoint.date
                currentGroup = [dataPoint]
            }
        }
        
        // Process final group
        if !currentGroup.isEmpty,
           let aggregatedPoint = aggregateGroup(currentGroup, method: method, groupDate: currentGroupStart) {
            aggregatedData.append(aggregatedPoint)
        }
        
        return aggregatedData
    }
    
    // MARK: - Private Methods
    
    private func determineAggregationLevel(
        dataCount: Int,
        period: TimePeriod,
        maxPoints: Int
    ) -> AggregationLevel {
        
        // If data count is within acceptable range, use daily
        if dataCount <= maxPoints {
            return .daily
        }
        
        // Use period-based aggregation with density considerations
        let periodAggregation = period.aggregationLevel
        
        // Override for very dense data
        switch dataCount {
        case 0...50:
            return .daily
        case 51...150:
            return periodAggregation == .daily ? .weekly : periodAggregation
        default:
            // Very dense data - force higher aggregation
            return periodAggregation == .daily ? .weekly :
                   periodAggregation == .weekly ? .monthly : .monthly
        }
    }
    
    private func aggregateByPeriod(
        _ data: [MetricDataPoint],
        level: AggregationLevel,
        method: AggregationMethod,
        preserveZeros: Bool
    ) -> [MetricDataPoint] {
        
        let calendar = Calendar.current
        var groups: [String: [MetricDataPoint]] = [:]
        
        // Group data points by time period
        for dataPoint in data {
            let groupKey = createGroupKey(for: dataPoint.date, level: level, calendar: calendar)
            groups[groupKey, default: []].append(dataPoint)
        }
        
        // Aggregate each group
        var aggregatedData: [MetricDataPoint] = []
        
        for (groupKey, groupData) in groups {
            let groupDate = parseGroupKey(groupKey, level: level, calendar: calendar)
            if let aggregatedPoint = aggregateGroup(groupData, method: method, groupDate: groupDate) {
                aggregatedData.append(aggregatedPoint)
            }
        }
        
        return aggregatedData.sorted { $0.date < $1.date }
    }
    
    private func createGroupKey(for date: Date, level: AggregationLevel, calendar: Calendar) -> String {
        let year = calendar.component(.year, from: date)
        
        switch level {
        case .daily:
            let month = calendar.component(.month, from: date)
            let day = calendar.component(.day, from: date)
            return "\(year)-\(month)-\(day)"
            
        case .weekly:
            let weekOfYear = calendar.component(.weekOfYear, from: date)
            return "\(year)-W\(weekOfYear)"
            
        case .monthly:
            let month = calendar.component(.month, from: date)
            return "\(year)-\(month)"
        }
    }
    
    private func parseGroupKey(_ groupKey: String, level: AggregationLevel, calendar: Calendar) -> Date {
        let components = groupKey.split(separator: "-")
        guard let year = Int(components[0]) else { return Date() }
        
        var dateComponents = DateComponents()
        dateComponents.year = year
        
        switch level {
        case .daily:
            if components.count >= 3,
               let month = Int(components[1]),
               let day = Int(components[2]) {
                dateComponents.month = month
                dateComponents.day = day
            }
            
        case .weekly:
            if components.count >= 2 {
                let weekString = String(components[1])
                if weekString.hasPrefix("W"),
                   let week = Int(String(weekString.dropFirst())) {
                    dateComponents.weekOfYear = week
                }
            }
            
        case .monthly:
            if components.count >= 2,
               let month = Int(components[1]) {
                dateComponents.month = month
                dateComponents.day = 1
            }
        }
        
        return calendar.date(from: dateComponents) ?? Date()
    }
    
    private func aggregateGroup(
        _ groupData: [MetricDataPoint],
        method: AggregationMethod,
        groupDate: Date
    ) -> MetricDataPoint? {
        
        guard !groupData.isEmpty else { return nil }
        
        let values = groupData.map { $0.value }
        let aggregatedValue: Double
        
        switch method {
        case .average:
            aggregatedValue = values.reduce(0, +) / Double(values.count)
            
        case .sum:
            aggregatedValue = values.reduce(0, +)
            
        case .frequency:
            // Calculate percentage of non-zero values
            let nonZeroCount = values.filter { $0 > 0 }.count
            aggregatedValue = Double(nonZeroCount) / Double(values.count) * 100.0
            
        case .mode:
            // Find most frequent value
            let frequencies = Dictionary(values.map { ($0, 1) }, uniquingKeysWith: +)
            aggregatedValue = frequencies.max(by: { $0.value < $1.value })?.key ?? 0
            
        case .latest:
            // Use the latest value in the group
            let sortedGroup = groupData.sorted { $0.date < $1.date }
            aggregatedValue = sortedGroup.last?.value ?? 0
        }
        
        return MetricDataPoint(
            date: groupDate,
            value: aggregatedValue,
            rawValue: groupData.map { $0.rawValue },
            metricId: groupData.first?.metricId ?? ""
        )
    }
}

// MARK: - Extension for Smart Aggregation Configuration

extension ChartDataAggregator {
    
    /// Get optimal aggregation configuration for a specific metric type
    func getOptimalConfig(for dataType: MetricDataType, dataCount: Int) -> AggregationConfig {
        
        let maxPoints: Int = {
            switch dataCount {
            case 0...30: return 30    // Show all data
            case 31...100: return 50  // Light aggregation
            case 101...300: return 40 // Medium aggregation  
            default: return 30        // Heavy aggregation
            }
        }()
        
        let method: AggregationMethod = {
            switch dataType {
            case .continuous:
                return .average
            case .binary:
                return .frequency
            case .categorical:
                return .mode
            case .count:
                return .sum
            case .percentage:
                return .average
            case .custom:
                return .average
            }
        }()
        
        let preserveZeros: Bool = {
            switch dataType {
            case .binary, .count:
                return true  // Important to show zero days
            default:
                return false
            }
        }()
        
        return AggregationConfig(
            maxDataPoints: maxPoints,
            method: method,
            preserveZeros: preserveZeros
        )
    }
    
    /// Preview aggregation without performing it (for UI feedback)
    func previewAggregation(
        dataCount: Int,
        period: TimePeriod,
        config: AggregationConfig = .default
    ) -> AggregatedDataInfo {
        
        let aggregationLevel = determineAggregationLevel(
            dataCount: dataCount,
            period: period,
            maxPoints: config.maxDataPoints
        )
        
        let estimatedAggregatedCount: Int = {
            switch aggregationLevel {
            case .daily:
                return dataCount
            case .weekly:
                return max(1, dataCount / 7)
            case .monthly:
                return max(1, dataCount / 30)
            }
        }()
        
        return AggregatedDataInfo(
            originalCount: dataCount,
            aggregatedCount: min(estimatedAggregatedCount, config.maxDataPoints),
            aggregationLevel: aggregationLevel,
            method: config.method
        )
    }
}