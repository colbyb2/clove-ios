import SwiftUI

// MARK: - Integration Test View

/// Simple test view to validate the new metrics system integration
struct MetricsIntegrationTestView: View {
    @State private var viewModel = InsightsV2ViewModel()
    @State private var showingMetricExplorer = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: CloveSpacing.large) {
                // Header
                Text("Metrics System Integration Test")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(CloveColors.primaryText)
                
                // Current Status
                VStack(alignment: .leading, spacing: CloveSpacing.medium) {
                    HStack {
                        Text("Status:")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(CloveColors.primaryText)
                        
                        Spacer()
                        
                        if viewModel.isLoadingMetricData {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading...")
                                    .font(CloveFonts.small())
                                    .foregroundStyle(CloveColors.secondaryText)
                            }
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(CloveColors.green)
                        }
                    }
                    
                    if let metric = viewModel.selectedMetric {
                        HStack {
                            Text(metric.icon)
                                .font(.system(size: 20))
                            
                            Text("Selected: \(metric.displayName)")
                                .font(CloveFonts.body())
                                .foregroundStyle(CloveColors.primaryText)
                        }
                        
                        Text("Data Points: \(viewModel.metricData.count)")
                            .font(CloveFonts.small())
                            .foregroundStyle(CloveColors.secondaryText)
                    } else {
                        Text("No metric selected")
                            .font(CloveFonts.body())
                            .foregroundStyle(CloveColors.secondaryText)
                    }
                }
                .padding(CloveSpacing.large)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .fill(CloveColors.card)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
                
                // Chart Display
                if viewModel.hasSelectedMetric() {
                    VStack(alignment: .leading, spacing: CloveSpacing.medium) {
                        Text("Chart Display Test")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(CloveColors.primaryText)
                        
                        if viewModel.isLoadingMetricData {
                            ProgressView("Loading chart data...")
                                .frame(height: 200)
                        } else if !viewModel.metricData.isEmpty {
                            viewModel.createChartView()
                        } else {
                            VStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 40))
                                    .foregroundStyle(CloveColors.secondaryText.opacity(0.5))
                                Text("No data available")
                                    .font(CloveFonts.body())
                                    .foregroundStyle(CloveColors.secondaryText)
                            }
                            .frame(height: 200)
                        }
                    }
                    .padding(CloveSpacing.large)
                    .background(
                        RoundedRectangle(cornerRadius: CloveCorners.medium)
                            .fill(CloveColors.card)
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    )
                }
                
                // Actions
                VStack(spacing: CloveSpacing.medium) {
                    Button("Select Metric") {
                        showingMetricExplorer = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.shared.accent)
                    
                    if viewModel.hasSelectedMetric() {
                        Button("Refresh Data") {
                            Task {
                                await viewModel.refreshCurrentMetric()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Spacer()
            }
            .padding(CloveSpacing.large)
            .background(CloveColors.background.ignoresSafeArea())
            .navigationTitle("Test")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingMetricExplorer) {
            MetricExplorer { metricId in
                Task {
                    await viewModel.selectMetric(id: metricId)
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.refreshCurrentMetric()
            }
        }
    }
}

// MARK: - Performance Test

struct MetricsPerformanceTestView: View {
    @State private var oldSystemTime: TimeInterval = 0
    @State private var newSystemTime: TimeInterval = 0
    @State private var isRunning = false
    
    var body: some View {
        VStack(spacing: CloveSpacing.large) {
            Text("Performance Comparison")
                .font(.system(.title, design: .rounded).weight(.bold))
            
            VStack(spacing: CloveSpacing.medium) {
                HStack {
                    Text("Old System:")
                    Spacer()
                    Text("\(String(format: "%.3f", oldSystemTime))s")
                        .fontWeight(.semibold)
                        .foregroundStyle(CloveColors.red)
                }
                
                HStack {
                    Text("New System:")
                    Spacer()
                    Text("\(String(format: "%.3f", newSystemTime))s")
                        .fontWeight(.semibold)
                        .foregroundStyle(CloveColors.green)
                }
                
                if oldSystemTime > 0 && newSystemTime > 0 {
                    let improvement = ((oldSystemTime - newSystemTime) / oldSystemTime) * 100
                    HStack {
                        Text("Improvement:")
                        Spacer()
                        Text("\(String(format: "%.1f", improvement))%")
                            .fontWeight(.bold)
                            .foregroundStyle(improvement > 0 ? CloveColors.green : CloveColors.red)
                    }
                }
            }
            .padding(CloveSpacing.large)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .fill(CloveColors.card)
            )
            
            Button("Run Performance Test") {
                runPerformanceTest()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunning)
            
            if isRunning {
                ProgressView("Running test...")
            }
        }
        .padding(CloveSpacing.large)
    }
    
    private func runPerformanceTest() {
        isRunning = true
        
        Task {
            // Test old system (ChartDataManager)
            let oldStart = CFAbsoluteTimeGetCurrent()
            let chartDataManager = ChartDataManager.shared
            let _ = chartDataManager.getAvailableMetrics()
            let _ = chartDataManager.getAvailableSymptoms()
            oldSystemTime = CFAbsoluteTimeGetCurrent() - oldStart
            
            // Test new system (MetricRegistry)
            let newStart = CFAbsoluteTimeGetCurrent()
            let metricRegistry = MetricRegistry.shared
            let _ = await metricRegistry.getMetricSummaries()
            newSystemTime = CFAbsoluteTimeGetCurrent() - newStart
            
            await MainActor.run {
                isRunning = false
            }
        }
    }
}

// MARK: - Preview

#Preview("Integration Test") {
    MetricsIntegrationTestView()
}

#Preview("Performance Test") {
    MetricsPerformanceTestView()
}