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
        
        let data = await metric.getDataPoints(for: timePeriodManager.selectedPeriod)
        self.metricData = data.sorted { $0.date < $1.date }
        
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
        
        // Check if we should use aggregated data
        let shouldAggregate = metricData.count > 50
        
        if shouldAggregate {
            return AnyView(
                AsyncChartView(
                    metric: metric,
                    period: timePeriodManager.selectedPeriod,
                    timeRange: getCurrentTimeRangeText()
                )
            )
        } else {
            return AnyView(
                UniversalChartEngine.createChart(
                    for: metric,
                    data: metricData,
                    timeRange: getCurrentTimeRangeText()
                )
            )
        }
    }
    
    @MainActor
    func loadAggregatedMetricData(maxPoints: Int = 50) async {
        guard let metric = selectedMetric else { return }
        
        isLoadingMetricData = true
        errorMessage = nil
        
        let (data, _) = await metric.getAggregatedDataPoints(for: timePeriodManager.selectedPeriod, maxPoints: maxPoints)
        self.metricData = data.sorted { $0.date < $1.date }
        
        isLoadingMetricData = false
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

// MARK: - Async Chart View

struct AsyncChartView: View {
    let metric: any MetricProvider
    let period: TimePeriod
    let timeRange: String
    let maxDataPoints: Int
    
    @State private var isLoading = true
    @State private var chartData: [MetricDataPoint] = []
    @State private var aggregationInfo: AggregatedDataInfo?
    
    init(metric: any MetricProvider, period: TimePeriod, timeRange: String, maxDataPoints: Int = 50) {
        self.metric = metric
        self.period = period
        self.timeRange = timeRange
        self.maxDataPoints = maxDataPoints
    }
    
    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Optimizing chart...")
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                }
                .frame(height: 200)
            } else {
                UniversalChartEngine.createChart(
                    for: metric,
                    data: chartData,
                    timeRange: timeRange,
                    aggregationInfo: aggregationInfo
                )
            }
        }
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        let (data, info) = await metric.getAggregatedDataPoints(for: period, maxPoints: maxDataPoints)
        
        await MainActor.run {
            self.chartData = data
            self.aggregationInfo = info
            self.isLoading = false
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
