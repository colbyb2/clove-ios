import Foundation
import SwiftUI

// MARK: - Insights V2 View Model

@Observable
class InsightsV2ViewModel {
    // MARK: - Published Properties
    
    var selectedMetricId: String?
    var selectedMetric: (any MetricProvider)?
    var metricData: [MetricDataPoint] = []
    var isLoadingMetricData = false
    var errorMessage: String?
    
    // Time period management
    var timePeriodManager = TimePeriodManager.shared
    
    // MARK: - Private Properties
    
    private let metricRegistry = MetricRegistry.shared
    private let dataLoader = OptimizedDataLoader.shared
    
    // MARK: - Initialization
    
    init() {
        // Initialize with default metric if available
        Task {
            await loadDefaultMetric()
        }
    }
    
    // MARK: - Public Methods
    
    @MainActor
    func selectMetric(id: String) async {
        selectedMetricId = id
        selectedMetric = await metricRegistry.getMetric(id: id)
        await loadMetricData()
    }
    
    @MainActor
    func loadMetricData() async {
        guard let metric = selectedMetric else { return }
        
        isLoadingMetricData = true
        errorMessage = nil
        
        do {
            let data = await metric.getDataPoints(for: timePeriodManager.selectedPeriod)
            self.metricData = data.sorted { $0.date < $1.date }
        } catch {
            self.errorMessage = "Failed to load metric data: \(error.localizedDescription)"
        }
        
        isLoadingMetricData = false
    }
    
    @MainActor
    func refreshCurrentMetric() async {
        // Clear caches and reload
        await dataLoader.clearSessionCache()
        metricRegistry.invalidateCache()
        await loadMetricData()
    }
    
    @MainActor
    func timePeriodChanged() async {
        // Reload data when time period changes
        await loadMetricData()
    }
    
    // MARK: - Helper Methods
    
    func getCurrentChartDataForUniversalChart() -> [MetricDataPoint] {
        return metricData
    }
    
    func getCurrentMetricName() -> String {
        return selectedMetric?.displayName ?? "Select a metric"
    }
    
    func getCurrentTimeRangeText() -> String {
        return timePeriodManager.currentPeriodDisplayText
    }
    
    func hasSelectedMetric() -> Bool {
        return selectedMetric != nil
    }
    
    func getAvailableMetricsCount() async -> Int {
        return await metricRegistry.getAvailableMetricCount()
    }
    
    // MARK: - Chart Integration Methods
    
    func createChartView() -> some View {
        guard let metric = selectedMetric else {
            return AnyView(EmptyChartPlaceholder())
        }
        
        return AnyView(
            UniversalChartEngine.createChart(
                for: metric,
                data: metricData,
                timeRange: getCurrentTimeRangeText()
            )
        )
    }
    
    func getMetricStatistics() -> MetricStatistics? {
        guard !metricData.isEmpty else { return nil }
        
        let values = metricData.map { $0.value }
        let sortedValues = values.sorted()
        
        let mean = values.reduce(0, +) / Double(values.count)
        let median = sortedValues.count % 2 == 0 ?
        (sortedValues[sortedValues.count / 2 - 1] + sortedValues[sortedValues.count / 2]) / 2 :
        sortedValues[sortedValues.count / 2]
        let min = sortedValues.first ?? 0
        let max = sortedValues.last ?? 0
        
        let trend = calculateTrend()
        let changePercentage = calculateChangePercentage()
        
        return MetricStatistics(
            mean: mean,
            median: median,
            min: min,
            max: max,
            count: metricData.count,
            trend: trend,
            changePercentage: changePercentage
        )
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func loadDefaultMetric() async {
        // Try to load a default metric (e.g., Mood)
        let availableMetrics = await metricRegistry.getAllAvailableMetrics()
        
        // Prioritize core health metrics
        if let moodMetric = availableMetrics.first(where: { $0.id == "mood" }) {
            selectedMetric = moodMetric
            selectedMetricId = moodMetric.id
        } else if let firstMetric = availableMetrics.first {
            selectedMetric = firstMetric
            selectedMetricId = firstMetric.id
        }
        
        if selectedMetric != nil {
            await loadMetricData()
        }
    }
    
    private func calculateTrend() -> MetricStatistics.TrendDirection {
        guard metricData.count >= 2 else { return .stable }
        
        let sortedData = metricData.sorted { $0.date < $1.date }
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
    
    private func calculateChangePercentage() -> Double {
        guard metricData.count >= 2 else { return 0 }
        
        let sortedData = metricData.sorted { $0.date < $1.date }
        guard let firstValue = sortedData.first?.value,
              let lastValue = sortedData.last?.value,
              firstValue != 0 else { return 0 }
        
        return ((lastValue - firstValue) / firstValue) * 100
    }
}

// MARK: - Backward Compatibility Methods

extension InsightsV2ViewModel {
    /// Legacy support - maps to new system
    var logs: [DailyLog] {
        // Return empty array as this is handled by the new system
        return []
    }
    
    var flareCount: Int {
        // Calculate from metric data if flare day metric is selected
        if selectedMetricId == "flare_day" {
            return metricData.filter { $0.value == 1.0 }.count
        }
        return 0
    }
    
    /// Legacy method for backward compatibility
    func loadLogs() {
        Task {
            await loadMetricData()
        }
    }
    
    /// Legacy method adapter
    func loadFoundationData() {
        Task {
            await refreshCurrentMetric()
        }
    }
}

// MARK: - Empty Chart Placeholder

struct EmptyChartPlaceholder: View {
    var body: some View {
        VStack(spacing: CloveSpacing.large) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(Theme.shared.accent.opacity(0.5))
            
            VStack(spacing: CloveSpacing.small) {
                Text("No Metric Selected")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Text("Choose a metric to view its data and trends")
                    .font(CloveFonts.body())
                    .foregroundStyle(CloveColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            Button("Select Metric") {
                // This would trigger the metric selector
                // Implementation depends on the parent view
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.shared.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(CloveSpacing.xlarge)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}
