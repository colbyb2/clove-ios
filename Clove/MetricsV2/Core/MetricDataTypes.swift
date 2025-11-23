import Foundation
import SwiftUI

// MARK: - Data Type Definitions

/// Defines the type of data a metric represents
enum MetricDataType: Sendable {
    case continuous(range: ClosedRange<Double>)  // 1-10 scale
    case binary                                 // 0/1, yes/no
    case categorical(values: [String])           // weather types, bowel movement types
    case count                                   // number of items
    case percentage                              // 0-100%
    case custom                                  // completely custom handling
}

/// Chart type for display
enum MetricChartType: Sendable {
    case line
    case area
    case bar
    case scatter
    case stackedBar
}

/// Unified data point structure for all metrics
struct MetricDataPoint: Identifiable, Sendable, Hashable {
    let id = UUID()
    let date: Date
    var value: Double
    let rawValue: (any Sendable)?  // Store original value for complex types
    let metricId: String
   
    
    init(date: Date, value: Double, rawValue: (any Sendable)? = nil, metricId: String) {
        self.date = date
        self.value = value
        self.rawValue = rawValue
        self.metricId = metricId
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(date)
        hasher.combine(value)
        hasher.combine(metricId)
    }
    
    static func == (lhs: MetricDataPoint, rhs: MetricDataPoint) -> Bool {
        lhs.id == rhs.id
    }
}

struct MetricChartStyle {
    var primary: Color
    var background: Color
    var text: Color
    
    static let `default` = MetricChartStyle(primary: Theme.shared.accent, background: CloveColors.card, text: CloveColors.secondaryText)
}

struct MetricChartConfig {
    let showAnnotation: Bool
    let showHeader: Bool
    let showFooter: Bool
    
    static let `default` = MetricChartConfig(showAnnotation: true, showHeader: true, showFooter: true)
}

/// Represents a formatted metric value
struct MetricValue: Sendable {
    let value: Double
    let rawValue: (any Sendable)?
    let formattedValue: String
    
    init(value: Double, rawValue: Any? = nil, formattedValue: String) {
        self.value = value
        self.rawValue = rawValue
        self.formattedValue = formattedValue
    }
}

/// Chart configuration for metrics
struct MetricChartConfiguration: Sendable {
    let chartType: MetricChartType
    let primaryColor: Color
    let showGradient: Bool
    let lineWidth: CGFloat
    let showDataPoints: Bool
    let enableInteraction: Bool
    
    static let `default` = MetricChartConfiguration(
        chartType: .line,
        primaryColor: Theme.shared.accent,
        showGradient: true,
        lineWidth: 3.0,
        showDataPoints: false,
        enableInteraction: true
    )
}

/// Statistics calculated from metric data
struct MetricStatistics: Sendable {
    let mean: Double
    let median: Double
    let min: Double
    let max: Double
    let count: Int
    let trend: TrendDirection
    let changePercentage: Double
    
    enum TrendDirection: Sendable {
        case increasing
        case decreasing
        case stable
    }
}

/// Summary information about a metric (for UI display without loading full data)
struct MetricSummary: Identifiable, Sendable, Hashable {
    let id: String
    let displayName: String
    let description: String
    let icon: String
    let category: MetricCategory
    let dataPointCount: Int
    let lastValue: String?
    let isAvailable: Bool
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: MetricSummary, rhs: MetricSummary) -> Bool {
        lhs.id == rhs.id
    }
}
