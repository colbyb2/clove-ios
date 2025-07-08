import SwiftUI
import Charts

struct FullScreenChartView: View {
    let data: [ChartDataPoint]
    let configuration: ChartConfiguration
    let metricName: String
    let timeRange: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDataPoint: ChartDataPoint?
    @State private var showingTooltip = false
    @State private var tooltipPosition: CGPoint = .zero
    @State private var showingRotationPrompt = true
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Main content
                    if geometry.size.width > geometry.size.height {
                        // Landscape layout
                        HStack(spacing: CloveSpacing.large) {
                            // Left side - Chart
                            VStack(spacing: CloveSpacing.medium) {
                                // Chart Header
                                chartHeader
                                
                                // Main Chart
                                chartView
                                    .frame(width: geometry.size.width * 0.7, height: geometry.size.height * 0.8)
                            }
                            
                            // Right side - Statistics
                            VStack(spacing: CloveSpacing.large) {
                                if !data.isEmpty {
                                    chartStatistics
                                }
                                Spacer()
                            }
                            .frame(width: geometry.size.width * 0.25)
                        }
                        .padding(CloveSpacing.large)
                    } else {
                        // Portrait layout - show rotation prompt
                        VStack(spacing: CloveSpacing.xlarge) {
                            Image(systemName: "iphone.landscape")
                                .font(.system(size: 60))
                                .foregroundStyle(Theme.shared.accent)
                            
                            VStack(spacing: CloveSpacing.medium) {
                                Text("Rotate for Better View")
                                    .font(.system(.title, design: .rounded).weight(.bold))
                                    .foregroundStyle(CloveColors.primaryText)
                                
                                Text("Turn your device to landscape mode for the best chart viewing experience.")
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(CloveColors.secondaryText)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(CloveSpacing.xlarge)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .background(CloveColors.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .overlay(alignment: .topTrailing) {
                // Close button
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                        .background(Color.clear)
                }
                .padding(.top, CloveSpacing.large)
                .padding(.trailing, CloveSpacing.xlarge)
            }
            .overlay {
                // Tooltip overlay
                if showingTooltip, let selectedPoint = selectedDataPoint {
                    tooltipView(for: selectedPoint)
                        .position(tooltipPosition)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(.none)
        .onAppear {
            // Request landscape orientation
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
               windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
            }
        }
        .onDisappear {
            // Return to portrait when dismissed  
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
               windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            }
        }
    }
    
    // MARK: - Chart Header
    
    private var chartHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: CloveSpacing.small) {
                Text(timeRange)
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(CloveColors.secondaryText)
            }
            
            Spacer()
            
            // Data point count
            Text("\(data.count) data points")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(CloveColors.secondaryText)
                .padding(.horizontal, CloveSpacing.medium)
                .padding(.vertical, CloveSpacing.small)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .fill(configuration.primaryColor.opacity(0.1))
                )
        }
    }
    
    // MARK: - Chart View
    
    private var chartView: some View {
        Chart(data) { dataPoint in
            switch configuration.chartType {
            case .line:
                lineChart(dataPoint)
            case .area:
                areaChart(dataPoint)
            case .bar:
                lineChart(dataPoint) // Fallback to line
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 6)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(CloveColors.secondaryText.opacity(0.2))
                AxisValueLabel()
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(CloveColors.secondaryText)
            }
        }
        .chartXAxis {
            AxisMarks(values: xAxisValues) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(CloveColors.secondaryText.opacity(0.2))
                AxisValueLabel(format: xAxisFormat)
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(CloveColors.secondaryText)
            }
        }
        .chartBackground { chartProxy in
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { location in
                    handleChartTap(at: location, chartProxy: chartProxy)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleChartDrag(value, chartProxy: chartProxy)
                        }
                        .onEnded { _ in
                            hideTooltipAfterDelay()
                        }
                )
        }
        .chartYScale(domain: yAxisDomain)
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.large)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
        )
    }
    
    // MARK: - Chart Types
    
    @ChartContentBuilder
    private func lineChart(_ dataPoint: ChartDataPoint) -> some ChartContent {
        LineMark(
            x: .value("Date", dataPoint.date),
            y: .value(metricName, dataPoint.value)
        )
        .foregroundStyle(configuration.primaryColor)
        .interpolationMethod(.catmullRom)
        .lineStyle(StrokeStyle(lineWidth: configuration.lineWidth * 1.5)) // Thicker line for fullscreen
        
        if configuration.showDataPoints {
            PointMark(
                x: .value("Date", dataPoint.date),
                y: .value(metricName, dataPoint.value)
            )
            .foregroundStyle(configuration.primaryColor)
            .symbolSize(selectedDataPoint?.id == dataPoint.id ? 80 : 50) // Larger points for fullscreen
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
        .lineStyle(StrokeStyle(lineWidth: configuration.lineWidth * 1.5))
    }
    
    // MARK: - Chart Statistics
    
    private var chartStatistics: some View {
        VStack(spacing: CloveSpacing.large) {
            Text(metricName)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(CloveColors.primaryText)
            
            if !data.isEmpty {
                let stats = ChartDataManager.shared.calculateStatistics(for: data)
                
                VStack(spacing: CloveSpacing.medium) {
                    StatView(title: "Average", value: formatValue(stats.mean, for: data.first?.metricType ?? .mood), color: configuration.primaryColor)
                    StatView(title: "Min", value: formatValue(stats.min, for: data.first?.metricType ?? .mood), color: CloveColors.blue)
                    StatView(title: "Max", value: formatValue(stats.max, for: data.first?.metricType ?? .mood), color: CloveColors.green)
                    StatView(title: "Trend", value: trendText(stats.trend), color: trendColor(stats.trend))
                    
                    if stats.changePercentage != 0 {
                        StatView(title: "Change", value: String(format: "%+.0f%%", stats.changePercentage), color: trendColor(stats.trend))
                    }
                }
            }
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.large)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Tooltip
    
    private func tooltipView(for dataPoint: ChartDataPoint) -> some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            Text(dataPoint.date.formatted(date: .complete, time: .omitted))
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(CloveColors.secondaryText)
            
            HStack(spacing: CloveSpacing.medium) {
                Circle()
                    .fill(configuration.primaryColor)
                    .frame(width: 12, height: 12)
                
                Text(metricName)
                    .font(.system(.title2, design: .rounded).weight(.medium))
                    .foregroundStyle(CloveColors.primaryText)
                
                Spacer()
                
                Text(formatValue(dataPoint.value, for: dataPoint.metricType))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(configuration.primaryColor)
            }
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.large)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .bottom)))
        .zIndex(100)
    }
    
    // MARK: - Interaction Handling
    
    private func handleChartTap(at location: CGPoint, chartProxy: ChartProxy) {
        let date: Date? = chartProxy.value(atX: location.x)
        guard let tappedDate = date else { return }
        
        let closestPoint = data.min { point1, point2 in
            abs(point1.date.timeIntervalSince(tappedDate)) < abs(point2.date.timeIntervalSince(tappedDate))
        }
        
        if let point = closestPoint {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedDataPoint = point
                showingTooltip = true
                
                let xPosition = chartProxy.position(forX: point.date) ?? location.x
                let yPosition = chartProxy.position(forY: point.value) ?? location.y
                
                tooltipPosition = CGPoint(x: xPosition, y: yPosition - 80)
            }
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            hideTooltipAfterDelay()
        }
    }
    
    private func handleChartDrag(_ value: DragGesture.Value, chartProxy: ChartProxy) {
        let date: Date? = chartProxy.value(atX: value.location.x)
        guard let draggedDate = date else { return }
        
        let closestPoint = data.min { point1, point2 in
            abs(point1.date.timeIntervalSince(draggedDate)) < abs(point2.date.timeIntervalSince(draggedDate))
        }
        
        if let point = closestPoint, point.id != selectedDataPoint?.id {
            selectedDataPoint = point
            showingTooltip = true
            
            let xPosition = chartProxy.position(forX: point.date) ?? value.location.x
            let yPosition = chartProxy.position(forY: point.value) ?? value.location.y
            
            tooltipPosition = CGPoint(x: xPosition, y: yPosition - 80)
            
            // Light haptic feedback for drag
            let selectionFeedback = UISelectionFeedbackGenerator()
            selectionFeedback.selectionChanged()
        }
    }
    
    private func hideTooltipAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showingTooltip = false
                selectedDataPoint = nil
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var xAxisValues: [Date] {
        guard !data.isEmpty else { return [] }
        
        let sortedData = data.sorted { $0.date < $1.date }
        let firstDate = sortedData.first!.date
        let lastDate = sortedData.last!.date
        
        let calendar = Calendar.current
        let totalDays = calendar.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0
        
        // More labels for fullscreen view
        let maxLabels: Int
        switch totalDays {
        case 0...7: maxLabels = min(7, data.count)
        case 8...30: maxLabels = 6
        case 31...90: maxLabels = 5
        default: maxLabels = 4
        }
        
        if data.count <= 2 {
            return [firstDate, lastDate]
        }
        
        var dates: [Date] = []
        for i in 0..<maxLabels {
            let fraction = Double(i) / Double(maxLabels - 1)
            let intervalFromStart = totalDays * Int(fraction)
            if let date = calendar.date(byAdding: .day, value: intervalFromStart, to: firstDate) {
                dates.append(date)
            }
        }
        
        return Array(Set(dates)).sorted()
    }
    
    private var xAxisFormat: Date.FormatStyle {
        let calendar = Calendar.current
        let totalDays = data.isEmpty ? 0 : calendar.dateComponents([.day], from: data.first!.date, to: data.last!.date).day ?? 0
        
        switch totalDays {
        case 0...7: return .dateTime.month(.abbreviated).day()
        case 8...30: return .dateTime.month(.abbreviated).day()
        case 31...90: return .dateTime.month(.abbreviated)
        default: return .dateTime.month(.abbreviated)
        }
    }
    
    private var yAxisDomain: ClosedRange<Double> {
        guard !data.isEmpty else { return 0...10 }
        
        let values = data.map { $0.value }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 10
        
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
        case .medication:
            return value == 1.0 ? "Taken" : "Not taken"
        case .activity:
            return value == 1.0 ? "Done" : "Not done"
        case .meal:
            return value == 1.0 ? "Eaten" : "Not eaten"
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

struct StatView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(CloveColors.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(color)
        }
        .padding(.vertical, CloveSpacing.small)
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
    
    FullScreenChartView(
        data: sampleData,
        configuration: ChartConfiguration.forMetricType(.mood),
        metricName: "Mood",
        timeRange: "7 Days"
    )
}
