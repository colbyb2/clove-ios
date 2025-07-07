import SwiftUI
import Charts

// MARK: - Chart Configuration

enum ChartType {
    case line
    case area
    case bar
}

struct ChartConfiguration {
    let chartType: ChartType
    let primaryColor: Color
    let showGradient: Bool
    let lineWidth: CGFloat
    let showDataPoints: Bool
    let enableInteraction: Bool
    
    static let `default` = ChartConfiguration(
        chartType: .line,
        primaryColor: Theme.shared.accent,
        showGradient: true,
        lineWidth: 3.0,
        showDataPoints: false,
        enableInteraction: true
    )
    
    static func forMetricType(_ metricType: MetricType) -> ChartConfiguration {
        switch metricType {
        case .mood, .painLevel, .energyLevel:
            return ChartConfiguration(
                chartType: .line,
                primaryColor: Theme.shared.accent,
                showGradient: true,
                lineWidth: 3.0,
                showDataPoints: false,
                enableInteraction: true
            )
        case .medicationAdherence:
            return ChartConfiguration(
                chartType: .area,
                primaryColor: CloveColors.blue,
                showGradient: true,
                lineWidth: 2.5,
                showDataPoints: true,
                enableInteraction: true
            )
        case .weather:
            return ChartConfiguration(
                chartType: .line,
                primaryColor: CloveColors.blue,
                showGradient: true,
                lineWidth: 3.0,
                showDataPoints: true,
                enableInteraction: true
            )
        case .flareDay, .activityCount, .mealCount:
            // These metrics are not available for charting
            return ChartConfiguration.default
        }
    }
}

// MARK: - Universal Chart View

struct UniversalChartView: View {
    let data: [ChartDataPoint]
    let configuration: ChartConfiguration
    let metricName: String
    let timeRange: String
    
    @State private var selectedDataPoint: ChartDataPoint?
    @State private var showingTooltip = false
    @State private var tooltipOffset: CGSize = .zero
    @State private var showingFullScreen = false
    
    init(data: [ChartDataPoint], metricName: String, timeRange: String, configuration: ChartConfiguration? = nil) {
        self.data = data
        self.metricName = metricName
        self.timeRange = timeRange
        self.configuration = configuration ?? ChartConfiguration.default
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
            FullScreenChartView(
                data: data,
                configuration: configuration,
                metricName: metricName,
                timeRange: timeRange
            )
        }
    }
    
    // MARK: - Chart Header
    
    private var chartHeader: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            HStack {
                Text(metricName)
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
                let stats = ChartDataManager.shared.calculateStatistics(for: data)
                HStack(spacing: CloveSpacing.large) {
                    StatisticView(title: "Average", value: String(format: "%.1f", stats.mean), color: configuration.primaryColor)
                    StatisticView(title: "Trend", value: trendText(stats.trend), color: trendColor(stats.trend))
                    if stats.changePercentage != 0 {
                        StatisticView(title: "Change", value: String(format: "%+.1f%%", stats.changePercentage), color: trendColor(stats.trend))
                    }
                }
            }
        }
    }
    
    // MARK: - Chart Container
    
    private var chartContainer: some View {
        Group {
            if data.isEmpty {
                emptyStateView
            } else {
                chartView
                    .frame(height: 200)
                    .clipped()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: CloveSpacing.medium) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundStyle(configuration.primaryColor.opacity(0.5))
            
            Text("No data available")
                .font(CloveFonts.body())
                .foregroundStyle(CloveColors.secondaryText)
            
            Text("Start logging to see your \(metricName.lowercased()) trends")
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
                // Bar charts are no longer supported
                lineChart(dataPoint)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(CloveColors.secondaryText.opacity(0.2))
                AxisValueLabel()
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
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
    private func lineChart(_ dataPoint: ChartDataPoint) -> some ChartContent {
        LineMark(
            x: .value("Date", dataPoint.date),
            y: .value(metricName, dataPoint.value)
        )
        .foregroundStyle(configuration.primaryColor)
        .interpolationMethod(.catmullRom)
        .lineStyle(StrokeStyle(lineWidth: configuration.lineWidth))
        
        if configuration.showDataPoints {
            PointMark(
                x: .value("Date", dataPoint.date),
                y: .value(metricName, dataPoint.value)
            )
            .foregroundStyle(configuration.primaryColor)
            .symbolSize(30)
        }
    }
    
    @ChartContentBuilder
    private func areaChart(_ dataPoint: ChartDataPoint) -> some ChartContent {
        AreaMark(
            x: .value("Date", dataPoint.date),
            y: .value(metricName, dataPoint.value)
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
            y: .value(metricName, dataPoint.value)
        )
        .foregroundStyle(configuration.primaryColor)
        .interpolationMethod(.catmullRom)
        .lineStyle(StrokeStyle(lineWidth: configuration.lineWidth))
    }
    
    
    // MARK: - Chart Footer
    
    private var chartFooter: some View {
        HStack {
            Text("\(data.count) data points")
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText)
            
            Spacer()
            
            if let firstPoint = data.first, let lastPoint = data.last {
                Text("\(firstPoint.date.formatted(date: .abbreviated, time: .omitted)) - \(lastPoint.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
            }
        }
    }
    
    // MARK: - Tooltip
    
    private func tooltipView(for dataPoint: ChartDataPoint) -> some View {
        VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
            Text(dataPoint.date.formatted(date: .abbreviated, time: .omitted))
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText)
            
            HStack(spacing: CloveSpacing.xsmall) {
                Circle()
                    .fill(configuration.primaryColor)
                    .frame(width: 8, height: 8)
                
                Text(metricName)
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.primaryText)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(formatValue(dataPoint.value, for: dataPoint.metricType))
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
    
    // MARK: - Interaction Handling
    
    private func handleChartTap() {
        guard configuration.enableInteraction else { return }
        
        // Show fullscreen chart view
        showingFullScreen = true
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    // MARK: - Helper Methods
    
    
    private var xAxisValues: [Date] {
        guard !data.isEmpty else { return [] }
        
        let sortedData = data.sorted { $0.date < $1.date }
        let firstDate = sortedData.first!.date
        let lastDate = sortedData.last!.date
        
        let calendar = Calendar.current
        let totalDays = calendar.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0
        
        // Be very conservative with label count to prevent overlapping
        let maxLabels: Int
        switch totalDays {
        case 0...7: maxLabels = min(4, data.count) // Max 4 labels for a week
        case 8...30: maxLabels = 4 // Max 4 labels for a month
        case 31...90: maxLabels = 3 // Max 3 labels for 3 months
        default: maxLabels = 3 // Max 3 labels for longer periods
        }
        
        // For very few data points, just show first and last
        if data.count <= 2 {
            return [firstDate, lastDate].compactMap { $0 }
        }
        
        // Generate strategic dates
        var dates: [Date] = []
        
        if maxLabels >= 1 {
            dates.append(firstDate)
        }
        
        if maxLabels >= 3 && totalDays > 1 {
            // Add middle date
            if let middleDate = calendar.date(byAdding: .day, value: totalDays / 2, to: firstDate) {
                dates.append(middleDate)
            }
        }
        
        if maxLabels >= 4 && totalDays > 2 {
            // Add quarter and three-quarter dates
            dates.removeAll() // Start fresh for 4-point layout
            dates.append(firstDate)
            
            if let quarterDate = calendar.date(byAdding: .day, value: totalDays / 4, to: firstDate) {
                dates.append(quarterDate)
            }
            
            if let threeQuarterDate = calendar.date(byAdding: .day, value: (totalDays * 3) / 4, to: firstDate) {
                dates.append(threeQuarterDate)
            }
            
            dates.append(lastDate)
        } else if maxLabels >= 2 && totalDays > 0 {
            dates.append(lastDate)
        }
        
        // Remove duplicates and sort
        let uniqueDates = Array(Set(dates)).sorted()
        
        return uniqueDates
    }
    
    private var xAxisFormat: Date.FormatStyle {
        let calendar = Calendar.current
        let totalDays = data.isEmpty ? 0 : calendar.dateComponents([.day], from: data.first!.date, to: data.last!.date).day ?? 0
        
        switch totalDays {
        case 0...7: return .dateTime.month(.abbreviated).day() // "Jan 1"
        case 8...30: return .dateTime.month(.abbreviated).day() // "Jan 1"  
        case 31...90: return .dateTime.month(.abbreviated) // "Jan"
        default: return .dateTime.month(.abbreviated) // "Jan"
        }
    }
    
    private var yAxisDomain: ClosedRange<Double> {
        guard !data.isEmpty else { return 0...10 }
        
        let values = data.map { $0.value }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 10
        
        // Add some padding to the range
        let padding = (maxValue - minValue) * 0.1
        let paddedMin = max(0, minValue - padding)
        let paddedMax = maxValue + padding
        
        return paddedMin...paddedMax
    }
    
    private func formatValue(_ value: Double, for metricType: MetricType) -> String {
        switch metricType {
        case .mood, .painLevel, .energyLevel:
            return String(format: "%.1f", value)
        case .medicationAdherence:
            return String(format: "%.0f%%", value)
        case .flareDay:
            return value == 1.0 ? "Yes" : "No"
        case .activityCount, .mealCount:
            return String(format: "%.0f", value)
        case .weather:
            return convertNumericToWeather(value)
        }
    }
    
    /// Convert numerical weather value back to readable string
    private func convertNumericToWeather(_ numericValue: Double) -> String {
        switch numericValue {
        case 1.0: return "Stormy"
        case 2.0: return "Rainy"
        case 3.0: return "Gloomy"
        case 4.0: return "Cloudy"
        case 5.0: return "Snow"
        case 6.0: return "Sunny"
        default: return "Mixed"
        }
    }
    
    private func trendText(_ trend: ChartStatistics.TrendDirection) -> String {
        switch trend {
        case .increasing: return "↗︎"
        case .decreasing: return "↘︎"
        case .stable: return "→"
        }
    }
    
    private func trendColor(_ trend: ChartStatistics.TrendDirection) -> Color {
        switch trend {
        case .increasing: return CloveColors.green
        case .decreasing: return CloveColors.red
        case .stable: return CloveColors.secondaryText
        }
    }
}

// MARK: - Supporting Views

struct StatisticView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText)
            
            Text(value)
                .font(CloveFonts.body())
                .foregroundStyle(color)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleData = [
        ChartDataPoint(date: Date().addingTimeInterval(-6*24*60*60), value: 7.2, metricType: .mood, metricName: "Mood", category: .coreHealth),
        ChartDataPoint(date: Date().addingTimeInterval(-5*24*60*60), value: 6.8, metricType: .mood, metricName: "Mood", category: .coreHealth),
        ChartDataPoint(date: Date().addingTimeInterval(-4*24*60*60), value: 8.1, metricType: .mood, metricName: "Mood", category: .coreHealth),
        ChartDataPoint(date: Date().addingTimeInterval(-3*24*60*60), value: 7.5, metricType: .mood, metricName: "Mood", category: .coreHealth),
        ChartDataPoint(date: Date().addingTimeInterval(-2*24*60*60), value: 8.3, metricType: .mood, metricName: "Mood", category: .coreHealth),
        ChartDataPoint(date: Date().addingTimeInterval(-1*24*60*60), value: 7.9, metricType: .mood, metricName: "Mood", category: .coreHealth),
        ChartDataPoint(date: Date(), value: 8.5, metricType: .mood, metricName: "Mood", category: .coreHealth)
    ]
    
    VStack(spacing: CloveSpacing.large) {
        UniversalChartView(
            data: sampleData,
            metricName: "Mood",
            timeRange: "7 Days",
            configuration: ChartConfiguration.forMetricType(.mood)
        )
        
        UniversalChartView(
            data: [],
            metricName: "Energy Level",
            timeRange: "30 Days",
            configuration: ChartConfiguration.forMetricType(.energyLevel)
        )
    }
    .padding()
    .background(CloveColors.background)
}
