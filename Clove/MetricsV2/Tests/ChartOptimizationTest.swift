import SwiftUI

// MARK: - Chart Optimization Test View

struct ChartOptimizationTestView: View {
    @State private var selectedDataSize: DataSize = .medium
    @State private var selectedTimePeriod: TimePeriod = .threeMonth
    @State private var showingAggregated = true
    
    enum DataSize: String, CaseIterable, Identifiable {
        case small = "Small (30 points)"
        case medium = "Medium (100 points)"  
        case large = "Large (300 points)"
        case huge = "Huge (500 points)"
        
        var id: String { rawValue }
        
        var pointCount: Int {
            switch self {
            case .small: return 30
            case .medium: return 100
            case .large: return 300
            case .huge: return 500
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: CloveSpacing.large) {
                    // Test Controls
                    testControlsSection
                    
                    // Performance Metrics
                    performanceSection
                    
                    // Chart Display
                    chartDisplaySection
                }
                .padding(CloveSpacing.large)
            }
            .background(CloveColors.background.ignoresSafeArea())
            .navigationTitle("Chart Optimization Test")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Test Controls
    
    private var testControlsSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            Text("Test Configuration")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(CloveColors.primaryText)
            
            VStack(spacing: CloveSpacing.medium) {
                // Data Size Picker
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    Text("Data Size")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Picker("Data Size", selection: $selectedDataSize) {
                        ForEach(DataSize.allCases) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Time Period Picker
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    Text("Time Period")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Picker("Time Period", selection: $selectedTimePeriod) {
                        ForEach(TimePeriod.allCases) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Aggregation Toggle
                Toggle("Use Smart Aggregation", isOn: $showingAggregated)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(CloveColors.primaryText)
            }
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Performance Section
    
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            Text("Expected Performance")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(CloveColors.primaryText)
            
            let aggregator = ChartDataAggregator.shared
            let config = aggregator.getOptimalConfig(for: .continuous(range: 0...10), dataCount: selectedDataSize.pointCount)
            let previewInfo = aggregator.previewAggregation(
                dataCount: selectedDataSize.pointCount,
                period: selectedTimePeriod,
                config: config
            )
            
            VStack(spacing: CloveSpacing.small) {
                performanceRow("Original Data Points", "\(selectedDataSize.pointCount)")
                performanceRow("Display Points", showingAggregated ? "\(previewInfo.aggregatedCount)" : "\(selectedDataSize.pointCount)")
                performanceRow("Aggregation Level", aggregationLevelText(previewInfo.aggregationLevel))
                performanceRow("Method", aggregationMethodText(previewInfo.method))
                
                if previewInfo.wasAggregated && showingAggregated {
                    performanceRow("Reduction", "\(String(format: "%.1f", previewInfo.reductionPercentage))%")
                        .foregroundStyle(CloveColors.green)
                }
            }
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private func performanceRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(CloveFonts.body())
                .foregroundStyle(CloveColors.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(CloveFonts.body())
                .fontWeight(.semibold)
                .foregroundStyle(CloveColors.primaryText)
        }
    }
    
    // MARK: - Chart Display Section
    
    private var chartDisplaySection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            Text("Chart Preview")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(CloveColors.primaryText)
            
            // Mock chart with synthetic data
            MockChartView(
                dataPointCount: selectedDataSize.pointCount,
                period: selectedTimePeriod,
                useAggregation: showingAggregated
            )
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Helper Methods
    
    private func aggregationLevelText(_ level: AggregationLevel) -> String {
        switch level {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
    
    private func aggregationMethodText(_ method: AggregationMethod) -> String {
        switch method {
        case .average: return "Average"
        case .sum: return "Sum"
        case .frequency: return "Frequency"
        case .mode: return "Mode"
        case .latest: return "Latest"
        }
    }
}

// MARK: - Mock Chart View

struct MockChartView: View {
    let dataPointCount: Int
    let period: TimePeriod
    let useAggregation: Bool
    
    @State private var isLoading = false
    @State private var mockData: [MetricDataPoint] = []
    @State private var aggregationInfo: AggregatedDataInfo?
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: CloveSpacing.medium) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Generating mock data...")
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                }
                .frame(height: 250)
            } else if mockData.isEmpty {
                VStack(spacing: CloveSpacing.medium) {
                    Button("Generate Mock Chart") {
                        generateMockData()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.shared.accent)
                }
                .frame(height: 250)
            } else {
                VStack(spacing: CloveSpacing.small) {
                    // Chart
                    MockUniversalChart(
                        data: mockData,
                        aggregationInfo: aggregationInfo
                    )
                    
                    // Chart Info
                    HStack {
                        Text("Displaying \(mockData.count) points")
                            .font(CloveFonts.small())
                            .foregroundStyle(CloveColors.secondaryText)
                        
                        Spacer()
                        
                        if let info = aggregationInfo, info.wasAggregated {
                            Text("Aggregated from \(info.originalCount)")
                                .font(CloveFonts.small())
                                .foregroundStyle(Theme.shared.accent)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .onAppear {
            generateMockData()
        }
        .onChange(of: dataPointCount) { _, _ in
            generateMockData()
        }
        .onChange(of: period) { _, _ in
            generateMockData()
        }
        .onChange(of: useAggregation) { _, _ in
            generateMockData()
        }
    }
    
    private func generateMockData() {
        isLoading = true
        
        Task {
            // Generate synthetic mood data
            let calendar = Calendar.current
            let endDate = Date()
            guard let startDate = calendar.date(byAdding: .day, value: -dataPointCount, to: endDate) else {
                await MainActor.run { isLoading = false }
                return
            }
            
            var syntheticData: [MetricDataPoint] = []
            
            for i in 0..<dataPointCount {
                guard let date = calendar.date(byAdding: .day, value: i, to: startDate) else { continue }
                
                // Generate realistic mood data with some trend and noise
                let baseValue = 5.0 + sin(Double(i) * 0.1) * 2.0 // Trending pattern
                let noise = Double.random(in: -1...1) // Random variation
                let value = max(1.0, min(10.0, baseValue + noise))
                
                syntheticData.append(MetricDataPoint(
                    date: date,
                    value: value,
                    rawValue: Int(value.rounded()),
                    metricId: "mock_mood"
                ))
            }
            
            let finalData: [MetricDataPoint]
            let info: AggregatedDataInfo?
            
            if useAggregation {
                let aggregator = ChartDataAggregator.shared
                let config = aggregator.getOptimalConfig(for: .continuous(range: 0...10), dataCount: syntheticData.count)
                let result = aggregator.aggregateData(syntheticData, for: period, config: config)
                finalData = result.data
                info = result.info
            } else {
                finalData = syntheticData
                info = nil
            }
            
            await MainActor.run {
                self.mockData = finalData
                self.aggregationInfo = info
                self.isLoading = false
            }
        }
    }
}

// MARK: - Mock Universal Chart

struct MockUniversalChart: View {
    let data: [MetricDataPoint]
    let aggregationInfo: AggregatedDataInfo?
    
    var body: some View {
        VStack(spacing: CloveSpacing.small) {
            Text("Mock Mood Data")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(CloveColors.primaryText)
            
            // Simple line chart representation
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.shared.accent.opacity(0.3),
                            Theme.shared.accent.opacity(0.1),
                            CloveColors.background
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 200)
                .overlay(
                    VStack {
                        HStack {
                            Text("10")
                                .font(CloveFonts.small())
                                .foregroundStyle(CloveColors.secondaryText)
                            Spacer()
                        }
                        Spacer()
                        HStack {
                            Text("1")
                                .font(CloveFonts.small())
                                .foregroundStyle(CloveColors.secondaryText)
                            Spacer()
                        }
                    }
                    .padding(CloveSpacing.small)
                )
                .overlay(
                    Text("📈 \(data.count) data points")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.shared.accent)
                )
            
            if let info = aggregationInfo, info.wasAggregated {
                HStack(spacing: CloveSpacing.xsmall) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.shared.accent)
                    
                    Text("Aggregated: \(aggregationLevelText(info.aggregationLevel)) • \(String(format: "%.1f", info.reductionPercentage))% reduction")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.shared.accent)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                .padding(CloveSpacing.small)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.small)
                        .fill(Theme.shared.accent.opacity(0.1))
                )
            }
        }
    }
    
    private func aggregationLevelText(_ level: AggregationLevel) -> String {
        switch level {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
}

// MARK: - Preview

#Preview {
    ChartOptimizationTestView()
}
