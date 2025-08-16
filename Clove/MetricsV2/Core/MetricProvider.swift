import Foundation
import SwiftUI

// MARK: - Core Protocol

/// Protocol that all metrics must implement to provide consistent data access and formatting
protocol MetricProvider: Identifiable, Sendable {
    // MARK: - Identification
    var id: String { get }
    var displayName: String { get }
    var description: String { get }
    var icon: String { get }
    var category: MetricCategory { get }
    
    // MARK: - Data Properties
    var dataType: MetricDataType { get }
    var chartType: MetricChartType { get }
    var valueRange: ClosedRange<Double>? { get }
    
    // MARK: - Data Access (Async for performance)
    func getDataPoints(for period: TimePeriod) async -> [MetricDataPoint]
    func getAggregatedDataPoints(for period: TimePeriod, maxPoints: Int) async -> (data: [MetricDataPoint], info: AggregatedDataInfo)
    func getDataPointCount() async -> Int
    func getDataPointCount(for period: TimePeriod) async -> Int
    func getLastValue() async -> MetricValue?
    
    // MARK: - Formatting
    func formatValue(_ value: Double) -> String
    func formatLastValue(_ value: MetricValue) -> String?
    
    // MARK: - Chart Configuration
    var chartConfiguration: MetricChartConfiguration { get }
}

// MARK: - Default Implementations

extension MetricProvider {
    /// Default chart configuration based on data type
    var chartConfiguration: MetricChartConfiguration {
        switch dataType {
        case .continuous:
            return MetricChartConfiguration(
                chartType: .line,
                primaryColor: Theme.shared.accent,
                showGradient: true,
                lineWidth: 3.0,
                showDataPoints: false,
                enableInteraction: true
            )
        case .binary:
            return MetricChartConfiguration(
                chartType: .line,
                primaryColor: Theme.shared.accent,
                showGradient: false,
                lineWidth: 3.0,
                showDataPoints: true,
                enableInteraction: true
            )
        case .categorical, .count:
            return MetricChartConfiguration(
                chartType: .bar,
                primaryColor: Theme.shared.accent,
                showGradient: true,
                lineWidth: 2.5,
                showDataPoints: true,
                enableInteraction: true
            )
        case .percentage:
            return MetricChartConfiguration(
                chartType: .area,
                primaryColor: CloveColors.blue,
                showGradient: true,
                lineWidth: 2.5,
                showDataPoints: true,
                enableInteraction: true
            )
        case .custom:
            return MetricChartConfiguration.default
        }
    }
    
    /// Default last value formatting
    func formatLastValue(_ value: MetricValue) -> String? {
        return value.formattedValue
    }
    
    /// Default data point count (gets count for current period)
    func getDataPointCount() async -> Int {
        return await getDataPointCount(for: TimePeriodManager.shared.selectedPeriod)
    }
    
    /// Default last value (gets from most recent data point)
    func getLastValue() async -> MetricValue? {
        let dataPoints = await getDataPoints(for: .week) // Get recent data
        guard let lastPoint = dataPoints.max(by: { $0.date < $1.date }) else { return nil }
        
        return MetricValue(
            value: lastPoint.value,
            rawValue: lastPoint.rawValue,
            formattedValue: formatValue(lastPoint.value)
        )
    }
    
    /// Default aggregated data points implementation
    func getAggregatedDataPoints(for period: TimePeriod, maxPoints: Int) async -> (data: [MetricDataPoint], info: AggregatedDataInfo) {
        let rawData = await getDataPoints(for: period)
        let aggregator = ChartDataAggregator.shared
        let config = aggregator.getOptimalConfig(for: dataType, dataCount: rawData.count)
        let configWithMaxPoints = AggregationConfig(
            maxDataPoints: maxPoints,
            method: config.method,
            preserveZeros: config.preserveZeros
        )
        
        return aggregator.aggregateData(rawData, for: period, config: configWithMaxPoints)
    }
}
