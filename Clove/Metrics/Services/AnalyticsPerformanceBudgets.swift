import Foundation

enum AnalyticsPerformanceBudgets {
    static let baselineHistoryYears = 10
    static let maximumDashboardRefreshSeconds = 2.0
    static let maximumIndexedLookupSeconds = 0.25
    static let maximumAutomaticDiscoveryTests = 60
    static let maximumLongRangeChartPoints = 132
    // Two fixed batched reads add custom definitions and daily values.
    static let maximumRepositoryStatements = 11
}
