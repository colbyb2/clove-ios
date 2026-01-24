import Foundation

/// Mock implementation of MetricRegistryProtocol for testing and previews
class MockMetricRegistry: MetricRegistryProtocol {
    var availableMetrics: [any MetricProvider] = []
    var metricsById: [String: any MetricProvider] = [:]

    init() {}

    func getAllAvailableMetrics() async -> [any MetricProvider] {
        return availableMetrics
    }

    func getMetric(id: String) async -> (any MetricProvider)? {
        return metricsById[id]
    }

    /// Factory with sample metrics for previews
    static func withSampleMetrics() -> MockMetricRegistry {
        let mock = MockMetricRegistry()
        // Sample metrics can be added here if needed for previews
        return mock
    }
}
