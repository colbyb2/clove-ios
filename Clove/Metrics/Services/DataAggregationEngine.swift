import SwiftUI

@Observable
class DataAggregationEngine {
    static let shared = DataAggregationEngine()
    
    struct ProcessingConfig {
        let shouldProcess: Bool
        let targetDataPoints: Int
        let loessBandwidth: Double
        let samplingStrategy: SamplingStrategy
        
        enum SamplingStrategy {
            case none           // Keep all data
            case uniform        // Take every Nth point
            case timeBasedGrid  // Sample at regular time intervals
        }
        
        static func config(for period: TimePeriod, dataPointCount: Int) -> ProcessingConfig {
            switch period {
            case .week, .month:
                // No processing needed - data is manageable
                return ProcessingConfig(
                    shouldProcess: false,
                    targetDataPoints: dataPointCount,
                    loessBandwidth: 0,
                    samplingStrategy: .none
                )
                
            case .threeMonth:
                // LOESS smoothing only, maybe light sampling
                return ProcessingConfig(
                    shouldProcess: dataPointCount > 60,
                    targetDataPoints: 45,
                    loessBandwidth: 0.15, // Light smoothing
                    samplingStrategy: dataPointCount > 100 ? .uniform : .none
                )
                
            case .sixMonth:
                // LOESS smoothing with moderate sampling
                return ProcessingConfig(
                    shouldProcess: dataPointCount > 80,
                    targetDataPoints: 50,
                    loessBandwidth: 0.2,
                    samplingStrategy: dataPointCount > 150 ? .timeBasedGrid : .uniform
                )
                
            case .year:
                // Stronger LOESS with time-based sampling
                return ProcessingConfig(
                    shouldProcess: dataPointCount > 100,
                    targetDataPoints: 60,
                    loessBandwidth: 0.25,
                    samplingStrategy: .timeBasedGrid
                )
                
            case .allTime:
                // Strong smoothing with smart sampling
                return ProcessingConfig(
                    shouldProcess: dataPointCount > 30,
                    targetDataPoints: 80,
                    loessBandwidth: 0.3,
                    samplingStrategy: .timeBasedGrid
                )
            }
        }
    }
    
    func processMetricData(
        points: [MetricDataPoint],
        period: TimePeriod,
        metricType: MetricDataType
    ) -> [MetricDataPoint] {
        guard !points.isEmpty else { return [] }
        
        let config = ProcessingConfig.config(for: period, dataPointCount: points.count)
        
        guard config.shouldProcess else {
            return points.sorted { $0.date < $1.date }
        }
        
        if case .binary = metricType {
            return processBinaryMetric(points: points, config: config)
        }
                
        let sortedPoints = points.sorted { $0.date < $1.date }
        
        // Step 2: Sample data if needed (BEFORE smoothing to preserve signal)
        let sampledPoints: [MetricDataPoint]
        switch config.samplingStrategy {
        case .none:
            sampledPoints = sortedPoints
            
        case .uniform:
            // Take every nth point to reduce density
            let step = max(1, sortedPoints.count / config.targetDataPoints)
            sampledPoints = stride(from: 0, to: sortedPoints.count, by: step).map {
                sortedPoints[$0]
            }
            
        case .timeBasedGrid:
            // Sample at regular time intervals
            sampledPoints = sampleAtTimeIntervals(
                points: sortedPoints,
                targetCount: config.targetDataPoints
            )
        }
        
        let smoothedPoints = applyLoessSmoothing(
            points: sampledPoints,
            bandwidth: config.loessBandwidth
        )
        
        
        return smoothedPoints
    }
    
    private func processBinaryMetric(points: [MetricDataPoint], config: ProcessingConfig) -> [MetricDataPoint] {
            let sortedPoints = points.sorted { $0.date < $1.date }
            
            // Calculate bucket interval based on time period
            let startDate = sortedPoints.first!.date
            let endDate = sortedPoints.last!.date
            let timeSpan = endDate.timeIntervalSince(startDate)
            let bucketInterval = timeSpan / Double(config.targetDataPoints)
            
            // Group points into time buckets
            var buckets: [Date: [MetricDataPoint]] = [:]
            
            for point in sortedPoints {
                let bucketIndex = floor(point.date.timeIntervalSince(startDate) / bucketInterval)
                let bucketStartTime = startDate.timeIntervalSince1970 + (bucketIndex * bucketInterval)
                let bucketCenterTime = bucketStartTime + (bucketInterval / 2)
                let bucketDate = Date(timeIntervalSince1970: bucketCenterTime)
                
                buckets[bucketDate, default: []].append(point)
            }
            
            // Calculate average for each bucket and round to 0 or 1
            let aggregatedPoints = buckets.compactMap { (bucketDate, bucketPoints) -> MetricDataPoint? in
                guard !bucketPoints.isEmpty else { return nil }
                
                let average = bucketPoints.map { $0.value }.reduce(0, +) / Double(bucketPoints.count)
                let roundedValue = average >= 0.5 ? 1.0 : 0.0
                
                return MetricDataPoint(
                    date: bucketDate,
                    value: roundedValue,
                    metricId: bucketPoints.first!.metricId
                )
            }.sorted { $0.date < $1.date }
            
            return aggregatedPoints
        }
    
    private func sampleAtTimeIntervals(points: [MetricDataPoint], targetCount: Int) -> [MetricDataPoint] {
        guard points.count > targetCount else { return points }
        
        let startDate = points.first!.date
        let endDate = points.last!.date
        let timeSpan = endDate.timeIntervalSince(startDate)
        let interval = timeSpan / Double(targetCount - 1)
        
        var sampledPoints: [MetricDataPoint] = []
        
        for i in 0..<targetCount {
            let targetTime = startDate.timeIntervalSince1970 + (Double(i) * interval)
            let targetDate = Date(timeIntervalSince1970: targetTime)
            
            // Find the point closest to this target time
            let closestPoint = points.min { point1, point2 in
                abs(point1.date.timeIntervalSince(targetDate)) <
                    abs(point2.date.timeIntervalSince(targetDate))
            }!
            
            sampledPoints.append(closestPoint)
        }
        
        // Remove duplicates while preserving order
        var seen = Set<UUID>()
        return sampledPoints.filter { point in
            if seen.contains(point.id) {
                return false
            } else {
                seen.insert(point.id)
                return true
            }
        }
    }
    
    private func applyLoessSmoothing(points: [MetricDataPoint], bandwidth: Double) -> [MetricDataPoint] {
        guard points.count > 2 else { return points }
        
        let n = points.count
        let windowSize = max(3, Int(Double(n) * bandwidth))
        
        return points.enumerated().map { index, point in
            // Determine window bounds
            let halfWindow = windowSize / 2
            let start = max(0, index - halfWindow)
            let end = min(n - 1, index + halfWindow)
            let window = Array(points[start...end])
            
            // Calculate weights based on temporal distance
            let weights = window.map { windowPoint in
                let timeDiff = abs(point.date.timeIntervalSince(windowPoint.date))
                let maxTimeDiff = points[end].date.timeIntervalSince(points[start].date)
                
                // Tricube weight function
                let normalizedDistance = maxTimeDiff > 0 ? timeDiff / maxTimeDiff : 0
                let weight = normalizedDistance < 1 ? pow(1 - pow(normalizedDistance, 3), 3) : 0
                
                return weight
            }
            
            // Weighted average that preserves the underlying signal
            let weightedSum = zip(window, weights).reduce(0) { sum, pair in
                sum + (pair.0.value * pair.1)
            }
            let totalWeight = weights.reduce(0, +)
            
            let smoothedValue = totalWeight > 0 ? weightedSum / totalWeight : point.value
            
            return MetricDataPoint(
                date: point.date, // Keep original date
                value: smoothedValue,
                metricId: point.metricId
            )
        }
    }
}
