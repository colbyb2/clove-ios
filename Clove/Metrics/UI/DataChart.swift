import SwiftUI
import Charts

struct ChartBuilder: View {
    var metric: any MetricProvider
    var data: [MetricDataPoint]
    var range: ClosedRange<Double>? = 1...10
    var style: MetricChartStyle = .default
    var timePeriod: TimePeriod = .month

    var config: MetricChartConfig = .default

    var onSelection: (MetricDataPoint?) -> Void = {_ in }

    @State private var selectedDate: Date?
    @State private var animationProgress: CGFloat = 0
    @State private var highlightedType: Double? = nil
    
    var selectedPoint: MetricDataPoint? {
        guard let selectedDate else { return nil }
        // Find the closest data point to the selected date
        return data.min(by: { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) })
    }
    
    var body: some View {
        ZStack {
            style.background
            VStack {
                switch metric.chartType {
                case .line:
                    LineChart()
                case .bar:
                    BarChart()
                case .stackedBar:
                    StackedBarChart()
                case .scatter:
                    ScatterChart()
                default:
                    LineChart()
                }
            }
        }
        .animation(.easeIn, value: animationProgress)
        .onAppear {
            animateGraph()
        }
        .onChange(of: selectedPoint) { _, val in
            onSelection(val)
        }
    }
    
    @ViewBuilder
    func ScatterChart() -> some View {
        Chart(data) { point in
            PointMark(x: .value("Date", point.date),
                      y: .value("Value", point.value)
            )
            .foregroundStyle(metric.dataType == .binary ? (point.value < 5 ? CloveColors.red : CloveColors.green) : Theme.shared.accent)
            .symbolSize(14)
            .opacity(animationProgress)
            
            if point.id == selectedPoint?.id {
                RuleMark(x: .value("Date", selectedPoint!.date))
                    .lineStyle(.init(lineWidth: 2, miterLimit: 2, dash: [2], dashPhase: 5))
                    .foregroundStyle(style.primary)
                    .annotation(position: .top) {
                        if let selectedPoint, config.showAnnotation {
                            Annotation(selectedPoint: selectedPoint)
                        }
                    }
            }
        }
        .padding(10)
        .chartYScale(domain: range ?? 0...1)
        .chartXSelection(value: $selectedDate)
        .chartYAxis {
            if metric.dataType != .binary {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine(
                        stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3])
                    )
                    .foregroundStyle(Color.secondary.opacity(0.2))
                    
                    if let v = value.as(Double.self) {
                        AxisValueLabel() {
                            Text(metric.formatValue(v))
                                .font(.caption)
                                .foregroundStyle(style.text)
                        }
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: getXAxisMarks()) { value in
                AxisGridLine(
                    stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3])
                )
                .foregroundStyle(Color.secondary.opacity(0.2))
                
                if let d = value.as(Date.self) {
                    AxisValueLabel() {
                        Text(formatDate(date: d))
                            .font(.caption)
                            .foregroundStyle(style.text)
                    }
                }
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .padding(.leading, 5)
        }
    }
    
    @ViewBuilder
    func LineChart() -> some View {
        Chart(data) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Value", point.value )
            )
            .interpolationMethod(timePeriod == .week ? .catmullRom : .linear)
            .foregroundStyle(style.primary)
            .lineStyle(StrokeStyle(lineWidth: 3))
            .opacity(animationProgress)
            
            PointMark(
                x: .value("Date", point.date),
                y: .value("Value", point.value )
            )
            .foregroundStyle(style.primary)
            .symbolSize(selectedPoint?.id == point.id ? 120 : 0)
            .opacity((selectedPoint == nil || selectedPoint?.id == point.id ? 1 : 0.3) * animationProgress)
            
            if point.id == selectedPoint?.id {
                RuleMark(x: .value("Date", selectedPoint!.date))
                    .lineStyle(.init(lineWidth: 2, miterLimit: 2, dash: [2], dashPhase: 5))
                    .foregroundStyle(style.primary)
                    .annotation(position: .top) {
                        if let selectedPoint, config.showAnnotation {
                            Annotation(selectedPoint: selectedPoint)
                        }
                    }
            }
        }
        .padding(10)
        .chartYScale(domain: range ?? 0...1)
        .chartXSelection(value: $selectedDate)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(
                    stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3])
                )
                .foregroundStyle(Color.secondary.opacity(0.2))
                
                if let v = value.as(Double.self) {
                    AxisValueLabel() {
                        Text(metric.formatValue(v))
                            .font(.caption)
                            .foregroundStyle(style.text)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: getXAxisMarks()) { value in
                AxisGridLine(
                    stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3])
                )
                .foregroundStyle(Color.secondary.opacity(0.2))
                
                if let d = value.as(Date.self) {
                    AxisValueLabel() {
                        Text(formatDate(date: d))
                            .font(.caption)
                            .foregroundStyle(style.text)
                    }
                }
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .padding(.leading, 5)
        }
    }
    
    @ViewBuilder
    func BarChart() -> some View {
        Chart(data) { point in
            BarMark(
                x: .value("Date", point.date),
                y: .value("", 1)
            )
            .foregroundStyle(point.value < 5 ? Color.gray : Theme.shared.accent)
            .opacity((selectedPoint == nil || point.id == selectedPoint?.id) ? animationProgress : 0.3)
        }
        .chartXSelection(value: $selectedDate)
        .chartYAxis {
            if metric.dataType != .binary {
                AxisMarks(position: .leading, values: getYAxisMarks()) { value in
                    AxisGridLine(
                        stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3])
                    )
                    .foregroundStyle(Color.secondary.opacity(0.2))
                    
                    if let v = value.as(Double.self) {
                        AxisValueLabel() {
                            Text(metric.formatValue(v))
                                .font(.caption)
                                .foregroundStyle(style.text)
                        }
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: getXAxisMarks()) { value in
                AxisGridLine(
                    stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3])
                )
                .foregroundStyle(Color.secondary.opacity(0.2))
                
                if let d = value.as(Date.self) {
                    AxisValueLabel() {
                        Text(formatDate(date: d))
                            .font(.caption)
                            .foregroundStyle(style.text)
                    }
                }
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .padding(5)
                .padding(.bottom, 10)
        }
        .overlay(alignment: .top) {
            if let selectedPoint, config.showAnnotation {
                VStack {
                    Annotation(selectedPoint: selectedPoint)
                    Spacer()
                }
                .padding(.top, 10)
            }
        }
    }
    
    @ViewBuilder
    func StackedBarChart() -> some View {
        let groupedData = DataGrouper.shared.getGroupedData(for: data, metric: metric)

        VStack(spacing: CloveSpacing.medium) {
            // Chart
            Chart(groupedData) { point in
                BarMark(
                    x: .value("Date", point.date),
                    y: .value("Count", point.count),
                    stacking: .standard
                )
                .foregroundStyle(getColorForValue(point.numericValue, metric: metric))
                .opacity(getBarOpacity(for: point))
                .position(by: .value("Value", point.value))
            }
            .chartXSelection(value: $selectedDate)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic()) { value in
                    AxisGridLine(
                        stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3])
                    )
                    .foregroundStyle(Color.secondary.opacity(0.2))

                    AxisValueLabel()
                }
            }
            .chartXAxis {
                AxisMarks(values: getXAxisMarks()) { value in
                    AxisGridLine(
                        stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3])
                    )
                    .foregroundStyle(Color.secondary.opacity(0.2))

                    if let d = value.as(Date.self) {
                        AxisValueLabel() {
                            Text(formatDate(date: d))
                                .font(.caption)
                                .foregroundStyle(style.text)
                        }
                    }
                }
            }
            .chartPlotStyle { plotArea in
                plotArea
                    .padding(5)
                    .padding(.bottom, 10)
            }
            .chartLegend(.hidden) // Hide default legend
            .overlay(alignment: .top) {
                if let selectedDate, config.showAnnotation {
                    VStack {
                        DetailedBarAnnotation(
                            date: selectedDate,
                            data: groupedData,
                            metric: metric,
                            colors: colorScheme,
                            timePeriod: timePeriod
                        )
                        Spacer()
                    }
                    .padding(.top, 10)
                }
            }

            // Custom Legend
            CustomChartLegend(
                metric: metric,
                data: groupedData,
                colors: colorScheme,
                highlightedType: $highlightedType
            )
        }
    }

    private func getBarOpacity(for point: GroupedDataPoint) -> Double {
        // Apply highlighting logic
        if let highlightedType = highlightedType {
            return point.numericValue == highlightedType ? animationProgress : 0.2
        } else if let selectedDate = selectedDate {
            let isSelected = Calendar.current.isDate(point.date, inSameDayAs: selectedDate)
            return isSelected ? animationProgress : 0.3
        } else {
            return animationProgress
        }
    }
    
    private var colorScheme: [Color] {
        // Generate color array using the same logic as getColorForValue
        let range = metric.valueRange ?? 1...5
        var colors: [Color] = []

        for value in stride(from: range.lowerBound, through: range.upperBound, by: 1.0) {
            colors.append(getColorForValue(value, metric: metric))
        }

        return colors
    }
    
    @ViewBuilder
    func Annotation(selectedPoint: MetricDataPoint) -> some View {
        Text("\(formatDate(date: selectedPoint.date)): \(metric.formatValue(selectedPoint.value))")
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .shadow(radius: 2)
            )
            .foregroundStyle(Color.white)
    }
    
    /// Animates the graph entrance
    func animateGraph() {
        animationProgress = 1
    }
    
    /// Returns the proper strides for x axis labels
    func getXAxisMarks() -> AxisMarkValues {
        switch timePeriod {
        case .week:
            return .stride(by: .day, count: 1)
        case .month:
            return .stride(by: .day, count: 5)
        case .threeMonth:
            return .stride(by: .day, count: 14)
        case .sixMonth:
            return .stride(by: .month, count: 1)
        case .year:
            return .stride(by: .month, count: 2)
        case .allTime:
            return .stride(by: .month, count: 6)
        }
    }
    
    /// Returns the proper strides for y axis labels
    func getYAxisMarks() -> AxisMarkValues {
        switch metric.dataType {
        case .continuous(range: _):
            return .automatic(desiredCount: 5)
        case .binary:
            return .automatic(desiredCount: 2)
        case .categorical(values: let cats):
            return .automatic(desiredCount: cats.count)
        case .count:
            return .automatic()
        case .percentage:
            return .automatic(desiredCount: 5)
        case .custom:
            return .automatic()
        }
    }
    
    func formatDate(date: Date) -> String {
        switch timePeriod {
        case .week:
            return date.formatted(.dateTime.month(.abbreviated).day(.twoDigits))
        case .month:
            return date.formatted(.dateTime.month(.abbreviated).day(.twoDigits))
        case .threeMonth:
            return date.formatted(.dateTime.month(.abbreviated).day(.twoDigits))
        case .sixMonth:
            return date.formatted(.dateTime.month(.abbreviated))
        case .year:
            return date.formatted(.dateTime.month(.abbreviated))
        case .allTime:
            return date.formatted(.dateTime.month(.abbreviated))
        }
    }
}

struct MetricChart: View {
    var metric: any MetricProvider
    var style: MetricChartStyle = .default
    var config: MetricChartConfig = .default
    
    let timeManager = TimePeriodManager.shared
    
    @State var data: [MetricDataPoint]? = nil
    
    var body: some View {
        ZStack {
            style.background
            
            VStack {
                if (config.showHeader || config.showStatsOnly){
                    Header()
                        .padding(.bottom, 10)
                }
                
                if let data {
                    if data.count > 1 {
                        ZStack {
                            ChartBuilder(metric: metric, data: data, range: metric.valueRange, style: style, timePeriod: timeManager.selectedPeriod, config: config)
                        }
                    } else {
                        EmptyStateView
                    }
                } else {
                    Text("Loading")
                }
                
                if timeManager.selectedPeriod != .week && timeManager.selectedPeriod != .month && config.showFooter {
                    Footer()
                }
            }
            .padding()
        }
        .task(id: metric.id) {
            await loadData()
        }
        .onChange(of: timeManager.selectedPeriod) { _, _ in
            Task {
                await loadData()
            }
        }
    }
    
    @ViewBuilder
    func Header() -> some View {
        VStack {
            if (!config.showStatsOnly) {
                HStack {
                    Text(metric.icon)
                        .font(.system(size: 26))
                    VStack(alignment: .leading) {
                        Text(metric.displayName)
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .foregroundStyle(CloveColors.primaryText)
                        Text(metric.description)
                            .foregroundStyle(CloveColors.secondaryText)
                    }
                    Spacer()
                }
                .padding(.bottom, 30)
            }
            
            HStack {
                Text(metric.displayName)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Spacer()
                
                Text(timeManager.currentPeriodShortText)
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
                    .padding(.horizontal, CloveSpacing.small)
                    .padding(.vertical, CloveSpacing.xsmall)
                    .background(
                        RoundedRectangle(cornerRadius: CloveCorners.small)
                            .fill(style.primary.opacity(0.1))
                    )
            }
            
            if let data, data.count > 1, !isBinaryMetric() {
                let stats = calculateStatistics(for: data)
                HStack(spacing: CloveSpacing.large) {
                    StatisticView(
                        title: "Average",
                        value: metric.formatValue(stats.mean),
                        color: style.primary
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
                    Spacer()
                }
            }
        }
    }
    
    @State var totalDataCount: Int = 0
    @State var isFooterExpanded: Bool = false
    
    @ViewBuilder
    func Footer() -> some View {
        VStack(spacing: 0) {
            FooterHeader()
            
            if isFooterExpanded {
                FooterExpandedContent()
            }
        }
        .task {
            totalDataCount = await metric.getDataPointCount(for: timeManager.selectedPeriod)
        }
    }
    
    @ViewBuilder
    private func FooterHeader() -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isFooterExpanded.toggle()
            }
        }) {
            HStack(spacing: CloveSpacing.small) {
                // Smart data indicator
                Image(systemName: "info.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CloveColors.info)
                
                Text("Smart Aggregation")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(CloveColors.secondaryText)
                
                Spacer()
                
                // Data compression badge
                HStack(spacing: 4) {
                    Text("\(data?.count ?? 0)")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                    Text("pts")
                        .font(.system(.caption2, design: .rounded))
                }
                .foregroundStyle(CloveColors.secondaryText)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(style.primary.opacity(0.4))
                )
                
                // Chevron with rotation animation
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(CloveColors.secondaryText)
                    .rotationEffect(.degrees(isFooterExpanded ? 0 : -90))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFooterExpanded)
            }
            .padding(.horizontal, CloveSpacing.medium)
            .padding(.vertical, CloveSpacing.small)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.small)
                    .fill(CloveColors.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: CloveCorners.small)
                            .stroke(style.primary.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func FooterExpandedContent() -> some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            // Explanation text
            VStack(alignment: .leading, spacing: CloveSpacing.small) {
                Text("Data Optimization")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Text(getSmartExplanation())
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(CloveColors.secondaryText)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            
            // Visual indicator
            if totalDataCount > (data?.count ?? 0) {
                DataOptimizationVisual()
            }
        }
        .padding(.horizontal, CloveSpacing.medium)
        .padding(.top, CloveSpacing.small)
        .padding(.bottom, CloveSpacing.medium)
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
    }
    
    @ViewBuilder
    private func DataOptimizationVisual() -> some View {
        HStack(spacing: CloveSpacing.medium) {
            // Data flow visualization
            VStack(spacing: 4) {
                Text("\(totalDataCount)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(CloveColors.secondaryText)
                Text("Original")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(CloveColors.secondaryText)
            }
            
            // Arrow
            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(style.primary)
            
            VStack(spacing: 4) {
                Text("\(data?.count ?? 0)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(style.primary)
                Text("Optimized")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(style.primary)
            }
            
            Spacer()
        }
        .padding(.horizontal, CloveSpacing.small)
        .padding(.vertical, CloveSpacing.xsmall)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.small)
                .fill(style.primary.opacity(0.05))
        )
    }
    
    private func getSmartExplanation() -> String {
        guard totalDataCount > (data?.count ?? 0) else {
            return "Showing all available data points for this time period."
        }
        
        let aggregationType = getAggregationType()
        
        switch timeManager.selectedPeriod {
        case .threeMonth:
            return "Your \(totalDataCount) daily entries are grouped into \(aggregationType) averages to reveal clearer patterns over 3 months."
        case .sixMonth:
            return "Data is intelligently combined into \(aggregationType) summaries, making 6-month trends easier to understand."
        case .year:
            return "A full year of data (\(totalDataCount) entries) simplified into \(aggregationType) insights for better trend analysis."
        case .allTime:
            return "All your historical data is optimized into meaningful \(aggregationType) patterns, preserving important trends while reducing visual clutter."
        default:
            return "Data points are smartly aggregated to show clearer long-term patterns."
        }
    }
    
    private func getAggregationType() -> String {
        switch timeManager.selectedPeriod {
        case .threeMonth:
            return "weekly"
        case .sixMonth, .year:
            return "monthly"
        case .allTime:
            return "monthly"
        default:
            return "grouped"
        }
    }
    
    private var EmptyStateView: some View {
        VStack(spacing: CloveSpacing.medium) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundStyle(style.primary.opacity(0.5))
            
            Text("Not enough data")
                .font(CloveFonts.body())
                .foregroundStyle(CloveColors.secondaryText)
            
            Text("Keep logging to see your \(metric.displayName.lowercased()) trends")
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
    
    func loadData() async {
        let metricData = await metric.getSmoothedData(for: timeManager.selectedPeriod)
        self.data = metricData
    }
    
    private func isBinaryMetric() -> Bool {
        switch metric.dataType {
        case .binary:
            return true
        default:
            return false
        }
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
}

fileprivate struct ChartPreview: View {
    let sampleMetricData: [MetricDataPoint] = {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -14, to: today)!  // 15 days ending today
        
        return (0..<15).map { i in
            let date = cal.date(byAdding: .day, value: i, to: start)!
            
            let value = Double.random(in: 1...9)
            
            return MetricDataPoint(date: date, value: value, metricId: "mood")
        }
    }()
    
    var body: some View {
        ZStack {
            CloveColors.background.ignoresSafeArea()
            
            MetricChart(metric: WeatherMetricProvider())
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding()
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

#Preview {
    ChartPreview()
        .onAppear {
            TimePeriodManager.shared.selectedPeriod = .threeMonth
        }
}
