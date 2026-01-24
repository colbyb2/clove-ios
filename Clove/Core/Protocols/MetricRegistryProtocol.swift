import Foundation

/// Protocol for metric registry operations used by ViewModels
protocol MetricRegistryProtocol: AnyObject {
    /// Get all available metrics with full data access
    func getAllAvailableMetrics() async -> [any MetricProvider]

    /// Get a specific metric by ID
    func getMetric(id: String) async -> (any MetricProvider)?
}

/// Conform MetricRegistry to the protocol
extension MetricRegistry: MetricRegistryProtocol {}
