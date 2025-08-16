import SwiftUI
import Charts

// MARK: - Universal Chart Engine

struct UniversalChartEngine {
    
    /// Create a chart view for any metric provider with automatic aggregation
    static func createOptimizedChart(
        for metric: any MetricProvider,
        period: TimePeriod,
        timeRange: String,
        maxDataPoints: Int = 50
    ) async -> some View {
        let (data, info) = await metric.getAggregatedDataPoints(for: period, maxPoints: maxDataPoints)
        return await UniversalMetricChart(
            metric: metric,
            data: data,
            timeRange: timeRange,
            aggregationInfo: info
        )
    }
    
    /// Create a chart view for any metric provider with its data
    static func createChart(
        for metric: any MetricProvider,
        data: [MetricDataPoint],
        timeRange: String
    ) -> some View {
        UniversalMetricChart(
            metric: metric,
            data: data,
            timeRange: timeRange
        )
    }
    
    /// Create a chart view with custom configuration
    static func createChart(
        for metric: any MetricProvider,
        data: [MetricDataPoint],
        timeRange: String,
        configuration: MetricChartConfiguration
    ) -> some View {
        UniversalMetricChart(
            metric: metric,
            data: data,
            timeRange: timeRange,
            customConfiguration: configuration
        )
    }
    
    /// Create a chart view with aggregation information
    static func createChart(
        for metric: any MetricProvider,
        data: [MetricDataPoint],
        timeRange: String,
        configuration: MetricChartConfiguration? = nil,
        aggregationInfo: AggregatedDataInfo? = nil
    ) -> some View {
        UniversalMetricChart(
            metric: metric,
            data: data,
            timeRange: timeRange,
            customConfiguration: configuration,
            aggregationInfo: aggregationInfo
        )
    }
}

// MARK: - Universal Metric Chart View

struct UniversalMetricChart: View {
    let metric: any MetricProvider
    let data: [MetricDataPoint]
    let timeRange: String
    let customConfiguration: MetricChartConfiguration?
    let aggregationInfo: AggregatedDataInfo?
    
    @State private var selectedDataPoint: MetricDataPoint?
    @State private var showingTooltip = false
    @State private var tooltipOffset: CGSize = .zero
    @State private var showingFullScreen = false
    
    init(
        metric: any MetricProvider,
        data: [MetricDataPoint],
        timeRange: String,
        customConfiguration: MetricChartConfiguration? = nil,
        aggregationInfo: AggregatedDataInfo? = nil
    ) {
        self.metric = metric
        self.data = data
        self.timeRange = timeRange
        self.customConfiguration = customConfiguration
        self.aggregationInfo = aggregationInfo
    }
    
    private var configuration: MetricChartConfiguration {
        customConfiguration ?? metric.chartConfiguration
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            // Chart Header
            chartHeader
            
            // Chart Container
            chartContainer
            
            // Chart Footer with Statistics
            if !data.isEmpty {
                chartFooter
            }
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .fullScreenCover(isPresented: $showingFullScreen) {
            FullScreenMetricChart(
                metric: metric,
                data: data,
                timeRange: timeRange,
                configuration: configuration
            )
        }
    }
    
    // MARK: - Chart Header
    
    private var chartHeader: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            HStack {
                Text(metric.displayName)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Spacer()
                
                Text(timeRange)
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
                    .padding(.horizontal, CloveSpacing.small)
                    .padding(.vertical, CloveSpacing.xsmall)
                    .background(
                        RoundedRectangle(cornerRadius: CloveCorners.small)
                            .fill(configuration.primaryColor.opacity(0.1))
                    )
            }
            
            if !data.isEmpty {
                let stats = calculateStatistics(for: data)
                HStack(spacing: CloveSpacing.large) {
                    StatisticView(
                        title: "Average",
                        value: metric.formatValue(stats.mean),
                        color: configuration.primaryColor
                    )
                    StatisticView(
                        title: "Trend",
                        value: trendText(stats.trend),
                        color: trendColor(stats.trend)
                    )
                    if stats.changePercentage != 0 {
                        StatisticView(
                            title: "Change",
                            value: String(format: "%+.1f%%", stats.changePercentage),
                            color: trendColor(stats.trend)
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Chart Container
    
    private var chartContainer: some View {
        Group {
            if data.isEmpty {
                emptyStateView.frame(height: 200).frame(maxWidth: .infinity)
            } else {
                chartView
                  .frame(minHeight: 240)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: CloveSpacing.medium) {
            Image(systemName: chartIconForDataType())
                .font(.system(size: 40))
                .foregroundStyle(configuration.primaryColor.opacity(0.5))
            
            Text("No data available")
                .font(CloveFonts.body())
                .foregroundStyle(CloveColors.secondaryText)
            
            Text("Start logging to see your \(metric.displayName.lowercased()) trends")
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
    
    private var chartView: some View {
        Chart(data) { dataPoint in
            switch configuration.chartType {
            case .line:
                lineChart(dataPoint)
            case .area:
                areaChart(dataPoint)
            case .bar:
                barChart(dataPoint)
            case .scatter:
                scatterChart(dataPoint)
            }
        }
        .chartYAxis {
            if isBinaryData() {
                // Binary data: show custom labels
                AxisMarks(position: .leading, values: [0.0, 1.0]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(CloveColors.secondaryText.opacity(0.2))
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(formatBinaryValue(doubleValue))
                                .font(CloveFonts.small())
                                .foregroundStyle(CloveColors.secondaryText)
                        }
                    }
                }
            } else {
                // Regular data: show automatic labels with custom formatting
                AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(CloveColors.secondaryText.opacity(0.2))
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(metric.formatValue(doubleValue))
                                .font(CloveFonts.small())
                                .foregroundStyle(CloveColors.secondaryText)
                        }
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: xAxisValues) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(CloveColors.secondaryText.opacity(0.2))
                AxisValueLabel(format: xAxisFormat)
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
            }
        }
        .chartXScale(domain: xAxisDomain)
        .chartOverlay { chart in
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    if configuration.enableInteraction {
                        handleChartTap()
                    }
                }
        }
        .overlay {
            if showingTooltip, let selectedPoint = selectedDataPoint {
                tooltipView(for: selectedPoint)
            }
        }
        .chartYScale(domain: yAxisDomain)
    }
    
    // MARK: - Chart Types Implementation
    
    @ChartContentBuilder
    private func lineChart(_ dataPoint: MetricDataPoint) -> some ChartContent {
        LineMark(
            x: .value("Date", dataPoint.date),
            y: .value(metric.displayName, dataPoint.value)
        )
        .foregroundStyle(configuration.primaryColor)
        .interpolationMethod(getOptimalInterpolationMethod())
        .lineStyle(StrokeStyle(lineWidth: getOptimalLineWidth()))
        
        if shouldShowDataPoints() {
            PointMark(
                x: .value("Date", dataPoint.date),
                y: .value(metric.displayName, dataPoint.value)
            )
            .foregroundStyle(configuration.primaryColor)
            .symbolSize(getOptimalPointSize())
        }
    }
    
    @ChartContentBuilder
    private func areaChart(_ dataPoint: MetricDataPoint) -> some ChartContent {
        AreaMark(
            x: .value("Date", dataPoint.date),
            y: .value(metric.displayName, dataPoint.value)
        )
        .foregroundStyle(
            configuration.showGradient ?
            LinearGradient(
                colors: [configuration.primaryColor.opacity(0.8), configuration.primaryColor.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            ) :
            LinearGradient(colors: [configuration.primaryColor], startPoint: .top, endPoint: .bottom)
        )
        .interpolationMethod(.catmullRom)
        
        LineMark(
            x: .value("Date", dataPoint.date),
            y: .value(metric.displayName, dataPoint.value)
        )
        .foregroundStyle(configuration.primaryColor)
        .interpolationMethod(getOptimalInterpolationMethod())
        .lineStyle(StrokeStyle(lineWidth: getOptimalLineWidth()))
    }
    
    @ChartContentBuilder
    private func barChart(_ dataPoint: MetricDataPoint) -> some ChartContent {
        BarMark(
            x: .value("Date", dataPoint.date),
            y: .value(metric.displayName, dataPoint.value)
        )
        .foregroundStyle(
            configuration.showGradient ?
            LinearGradient(
                colors: [configuration.primaryColor, configuration.primaryColor.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            ) :
               LinearGradient(
                   colors: [configuration.primaryColor],
                   startPoint: .top,
                   endPoint: .bottom
               )
            
        )
    }
    
    @ChartContentBuilder
    private func scatterChart(_ dataPoint: MetricDataPoint) -> some ChartContent {
        PointMark(
            x: .value("Date", dataPoint.date),
            y: .value(metric.displayName, dataPoint.value)
        )
        .foregroundStyle(configuration.primaryColor)
        .symbolSize(60)
    }
    
    // MARK: - Chart Footer
    
    private var chartFooter: some View {
        VStack(spacing: CloveSpacing.xsmall) {
            HStack {
                dataPointsInfo
                Spacer()
                dateRangeInfo
            }
            
            if let info = aggregationInfo, info.wasAggregated {
                aggregationIndicator(info)
            }
        }
    }
    
    private var dataPointsInfo: some View {
        let sortedData = data.sorted { $0.date < $1.date }
        let dateRange = !sortedData.isEmpty ? 
            "\(sortedData.first!.date.formatted(.dateTime.month().day())) - \(sortedData.last!.date.formatted(.dateTime.month().day()))" : "No data"
        
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(data.count) data points")
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText)
            Text(dateRange)
                .font(.system(size: 9))
                .foregroundStyle(CloveColors.secondaryText.opacity(0.7))
        }
    }
    
    private var dateRangeInfo: some View {
        Group {
            if let firstPoint = data.first, let lastPoint = data.last {
                Text("\(firstPoint.date.formatted(date: .abbreviated, time: .omitted)) - \(lastPoint.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
            }
        }
    }
    
    private func aggregationIndicator(_ info: AggregatedDataInfo) -> some View {
        HStack(spacing: CloveSpacing.xsmall) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 10))
                .foregroundStyle(Theme.shared.accent.opacity(0.7))
            
            Text("Aggregated from \(info.originalCount) points • \(aggregationLevelText(info.aggregationLevel)) averages")
                .font(.system(size: 10))
                .foregroundStyle(Theme.shared.accent.opacity(0.8))
                .fontWeight(.medium)
            
            Spacer()
        }
        .padding(.horizontal, CloveSpacing.small)
        .padding(.vertical, CloveSpacing.xsmall)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.small)
                .fill(Theme.shared.accent.opacity(0.1))
        )
    }
    
    private func aggregationLevelText(_ level: AggregationLevel) -> String {
        switch level {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
    
    // MARK: - Tooltip
    
    private func tooltipView(for dataPoint: MetricDataPoint) -> some View {
        VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
            Text(dataPoint.date.formatted(date: .abbreviated, time: .omitted))
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText)
            
            HStack(spacing: CloveSpacing.xsmall) {
                Circle()
                    .fill(configuration.primaryColor)
                    .frame(width: 8, height: 8)
                
                Text(metric.displayName)
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.primaryText)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(metric.formatValue(dataPoint.value))
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.primaryText)
                    .fontWeight(.bold)
            }
        }
        .padding(CloveSpacing.small)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.small)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .offset(tooltipOffset)
        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .bottom)))
        .zIndex(1)
    }
    
    // MARK: - Helper Methods
    
    private func handleChartTap() {
        guard configuration.enableInteraction else { return }
        
        showingFullScreen = true
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func isBinaryData() -> Bool {
        switch metric.dataType {
        case .binary:
            return true
        case .continuous(let range):
            // Check if all values are effectively binary (0/1)
            let uniqueValues = Set(data.map { $0.value })
            return uniqueValues.isSubset(of: [0.0, 1.0]) && range.lowerBound >= 0 && range.upperBound <= 1
        default:
            return false
        }
    }
    
    private func formatBinaryValue(_ value: Double) -> String {
        switch metric.dataType {
        case .binary:
            return metric.formatValue(value)
        default:
            return value == 1.0 ? "Yes" : "No"
        }
    }
    
    private func chartIconForDataType() -> String {
        switch metric.dataType {
        case .continuous: return "chart.line.uptrend.xyaxis"
        case .binary: return "chart.bar.fill"
        case .categorical: return "chart.dots.scatter"
        case .count: return "chart.bar.doc.horizontal"
        case .percentage: return "chart.pie"
        case .custom: return "chart.xyaxis.line"
        }
    }
    
    private var xAxisDomain: ClosedRange<Date> {
        guard !data.isEmpty else {
            let now = Date()
            return now...Calendar.current.date(byAdding: .day, value: 1, to: now)!
        }
        
        let sortedData = data.sorted { $0.date < $1.date }
        let firstDate = sortedData.first!.date
        let lastDate = sortedData.last!.date
        
        // Add padding to ensure full visibility
        let calendar = Calendar.current
        let totalDays = calendar.dateComponents([.day], from: firstDate, to: lastDate).day ?? 1
        let paddingDays = max(1, totalDays / 20) // 5% padding
        
        let startDate = calendar.date(byAdding: .day, value: -paddingDays, to: firstDate) ?? firstDate
        let endDate = calendar.date(byAdding: .day, value: paddingDays, to: lastDate) ?? lastDate
        
        return startDate...endDate
    }
    
    private var xAxisValues: [Date] {
        guard !data.isEmpty else { return [] }
        
        let sortedData = data.sorted { $0.date < $1.date }
        let firstDate = sortedData.first!.date
        let lastDate = sortedData.last!.date
        
        let calendar = Calendar.current
        let totalDays = calendar.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0
        
        // More intelligent axis tick calculation
        let maxLabels: Int
        let intervalType: Calendar.Component
        let intervalValue: Int
        
        switch totalDays {
        case 0...7:
            maxLabels = min(data.count, 7)
            intervalType = .day
            intervalValue = max(1, totalDays / maxLabels)
        case 8...30:
            maxLabels = 5
            intervalType = .day
            intervalValue = max(1, totalDays / maxLabels)
        case 31...90:
            maxLabels = 4
            intervalType = .weekOfYear
            intervalValue = max(1, (totalDays / 7) / maxLabels)
        default:
            maxLabels = 4
            intervalType = .month
            intervalValue = 1
        }
        
        // Generate evenly spaced dates
        var dates: [Date] = []
        var currentDate = firstDate
        
        while currentDate <= lastDate && dates.count < maxLabels {
            dates.append(currentDate)
            if let nextDate = calendar.date(byAdding: intervalType, value: intervalValue, to: currentDate) {
                currentDate = nextDate
            } else {
                break
            }
        }
        
        // Ensure we always include the last date if it's significantly different
        if let lastAddedDate = dates.last,
           calendar.dateComponents([.day], from: lastAddedDate, to: lastDate).day ?? 0 > intervalValue {
            dates.append(lastDate)
        }
        
        return dates
    }
    
    private var xAxisFormat: Date.FormatStyle {
        guard !data.isEmpty else {
            return .dateTime.month(.abbreviated).day()
        }
        
        let calendar = Calendar.current
        let sortedData = data.sorted { $0.date < $1.date }
        let totalDays = calendar.dateComponents([.day], from: sortedData.first!.date, to: sortedData.last!.date).day ?? 0
        
        switch totalDays {
        case 0...7: 
            return .dateTime.month(.abbreviated).day()
        case 8...30: 
            return .dateTime.month(.abbreviated).day()
        case 31...90: 
            return .dateTime.month(.abbreviated).day()
        case 91...365:
            return .dateTime.month(.abbreviated)
        default: 
            return .dateTime.month(.abbreviated).year(.defaultDigits)
        }
    }
    
    private var yAxisDomain: ClosedRange<Double> {
        guard !data.isEmpty else {
            if let range = metric.valueRange {
                return range
            }
            return 0...10
        }
        
        let values = data.map { $0.value }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 10
        
        // Use metric's defined range if available
        if let range = metric.valueRange {
            return range
        }
        
        // For binary data, use fixed domain
        if isBinaryData() {
            return -0.1...1.1
        }
        
        // Add padding for continuous data
        let padding = (maxValue - minValue) * 0.1
        let paddedMin = max(0, minValue - padding)
        let paddedMax = maxValue + padding
        
        return paddedMin...paddedMax
    }
    
    private func calculateStatistics(for data: [MetricDataPoint]) -> MetricStatistics {
        guard !data.isEmpty else {
            return MetricStatistics(mean: 0, median: 0, min: 0, max: 0, count: 0, trend: .stable, changePercentage: 0)
        }
        
        let values = data.map { $0.value }
        let sortedValues = values.sorted()
        
        let mean = values.reduce(0, +) / Double(values.count)
        let median = sortedValues.count % 2 == 0 ?
        (sortedValues[sortedValues.count / 2 - 1] + sortedValues[sortedValues.count / 2]) / 2 :
        sortedValues[sortedValues.count / 2]
        let min = sortedValues.first ?? 0
        let max = sortedValues.last ?? 0
        
        let trend = calculateTrend(for: data)
        let changePercentage = calculateChangePercentage(for: data)
        
        return MetricStatistics(
            mean: mean,
            median: median,
            min: min,
            max: max,
            count: data.count,
            trend: trend,
            changePercentage: changePercentage
        )
    }
    
    private func calculateTrend(for data: [MetricDataPoint]) -> MetricStatistics.TrendDirection {
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
    
    private func calculateChangePercentage(for data: [MetricDataPoint]) -> Double {
        guard data.count >= 2 else { return 0 }
        
        let sortedData = data.sorted { $0.date < $1.date }
        guard let firstValue = sortedData.first?.value,
              let lastValue = sortedData.last?.value,
              firstValue != 0 else { return 0 }
        
        return ((lastValue - firstValue) / firstValue) * 100
    }
    
    private func trendText(_ trend: MetricStatistics.TrendDirection) -> String {
        switch trend {
        case .increasing: return "↗︎"
        case .decreasing: return "↘︎"
        case .stable: return "→"
        }
    }
    
    private func trendColor(_ trend: MetricStatistics.TrendDirection) -> Color {
        switch trend {
        case .increasing: return CloveColors.green
        case .decreasing: return CloveColors.red
        case .stable: return CloveColors.secondaryText
        }
    }
    
    // MARK: - Chart Optimization Methods
    
    private func getOptimalInterpolationMethod() -> InterpolationMethod {
        let dataCount = data.count
        
        // Use different interpolation methods based on data density and type
        if isBinaryData() {
            return .stepStart // Better for binary data
        } else if dataCount > 100 {
            return .linear // Prevents rendering artifacts with dense data
        } else if dataCount > 50 {
            return .cardinal // Smoother but more controlled than catmullRom
        } else {
            return .catmullRom // Smoothest for sparse data
        }
    }
    
    private func getOptimalLineWidth() -> CGFloat {
        let baseWidth = configuration.lineWidth
        let dataCount = data.count
        
        // Thinner lines for very dense data
        if dataCount > 150 {
            return max(1.0, baseWidth * 0.6)
        } else if dataCount > 100 {
            return max(1.5, baseWidth * 0.8)
        } else {
            return baseWidth
        }
    }
    
    private func shouldShowDataPoints() -> Bool {
        if configuration.showDataPoints {
            let dataCount = data.count
            // Hide points for very dense data
            return dataCount <= 30
        }
        return false
    }
    
    private func getOptimalPointSize() -> CGFloat {
        let dataCount = data.count
        
        // Smaller points for denser data
        if dataCount > 20 {
            return 20
        } else if dataCount > 10 {
            return 25
        } else {
            return 30
        }
    }
}

// MARK: - Full Screen Chart View

struct FullScreenMetricChart: View {
    let metric: any MetricProvider
    let data: [MetricDataPoint]
    let timeRange: String
    let configuration: MetricChartConfiguration
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            UniversalMetricChart(
                metric: metric,
                data: data,
                timeRange: timeRange,
                customConfiguration: configuration
            )
            .padding(CloveSpacing.large)
            .background(CloveColors.background.ignoresSafeArea())
            .navigationTitle(metric.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
