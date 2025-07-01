import SwiftUI

struct InsightsView: View {
    @State private var viewModel = InsightsViewModel()
    @State private var showingMetricSelector = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: CloveSpacing.large) {
                    // Time period selector header
                    timePeriodSelectorSection
                    
                    // Current functionality (temporary during transition)
                    if !viewModel.logs.isEmpty {
                        // legacyChartsSection
                    }
                    
                    // New metric exploration section
                    metricExplorationSection
                    
                    // Smart Insights section
                    smartInsightsSection
                    
                    // Foundation preview section
                    foundationPreviewSection
                }
                .padding(.horizontal, CloveSpacing.large)
                .padding(.bottom, CloveSpacing.xlarge)
            }
            .background(CloveColors.background.ignoresSafeArea())
            .navigationTitle("Health Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingMetricSelector = true
                    } label: {
                        HStack(spacing: CloveSpacing.xsmall) {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .font(.system(size: 14))
                            Text("Explore")
                                .font(CloveFonts.small())
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, CloveSpacing.small)
                        .padding(.vertical, CloveSpacing.xsmall)
                        .background(
                            RoundedRectangle(cornerRadius: CloveCorners.full)
                                .fill(
                                    LinearGradient(
                                        colors: [CloveColors.accent, CloveColors.accent.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: CloveColors.accent.opacity(0.3), radius: 4, x: 0, y: 2)
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showingMetricSelector) {
            MetricSelectorView { metric in
                viewModel.selectMetricForChart(metric)
            }
        }
        .onAppear {
            viewModel.loadFoundationData()
        }
        .onChange(of: viewModel.timePeriodManager.selectedPeriod) { _, newPeriod in
            viewModel.refreshCurrentMetricData()
        }
    }
    
    // MARK: - Time Period Selector Section
    
    private var timePeriodSelectorSection: some View {
        VStack(spacing: CloveSpacing.medium) {
            HStack {
                Text("Time Period")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Spacer()
                
                Text(viewModel.timePeriodManager.currentPeriodDisplayText)
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
                    .id(viewModel.timePeriodManager.selectedPeriod.rawValue)
            }
            
            // Time period segmented control
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CloveSpacing.small) {
                    ForEach(TimePeriod.allCases) { period in
                        InsightsTimePeriodChip(
                            period: period,
                            isSelected: viewModel.timePeriodManager.selectedPeriod == period,
                            onTap: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    viewModel.timePeriodManager.selectedPeriod = period
                                    viewModel.refreshCurrentMetricData()
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, CloveSpacing.medium)
                .id(viewModel.timePeriodManager.selectedPeriod.rawValue)
            }
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Legacy Charts Section (temporary)
    
    private var legacyChartsSection: some View {
        VStack(spacing: CloveSpacing.large) {
            VStack(alignment: .leading, spacing: CloveSpacing.medium) {
                Text("Current Charts")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(CloveColors.primaryText)
                
                VStack(spacing: CloveSpacing.large) {
                    MoodGraphView(logs: viewModel.logs)
                    PainEnergyGraphView(logs: viewModel.logs)
                    SymptomSummaryView(logs: viewModel.logs)
                }
            }
            .padding(CloveSpacing.large)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .fill(CloveColors.card)
                    .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
            )
            
            if viewModel.flareCount > 0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    
                    Text("Flare-ups this month: \(viewModel.flareCount)")
                        .font(CloveFonts.body())
                        .foregroundStyle(CloveColors.primaryText)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                .padding(CloveSpacing.large)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .fill(Color.orange.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: CloveCorners.medium)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    // MARK: - New Metric Exploration Section
    
    private var metricExplorationSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.large) {
            HStack {
                Text("Metric Explorer")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Spacer()
                
                Button("Browse All") {
                    showingMetricSelector = true
                }
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.accent)
                .fontWeight(.semibold)
            }
            .padding(.horizontal)
            
            if let selectedMetric = viewModel.selectedMetricForChart {
                // Show selected metric chart
                selectedMetricChartView(metric: selectedMetric)
            } else {
                // Show metric selection prompt
                metricSelectionPromptView
            }
        }
        .padding(.horizontal, CloveSpacing.small)
        .padding(.vertical, CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        )
    }
    
    private func selectedMetricChartView(metric: SelectableMetric) -> some View {
        VStack(spacing: CloveSpacing.medium) {
            // Metric info header
            HStack {
                Text(metric.icon)
                    .font(.system(size: 24))
                
                VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
                    Text(metric.name)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text(metric.description)
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                        .lineLimit(2)
                }
                
                Spacer()
                
            }
            
            // Chart display
            if viewModel.isLoadingChartData {
                InsightsLoadingChartView()
            } else {
                let chartData = viewModel.getCurrentChartDataForUniversalChart()
                if !chartData.isEmpty {
                    UniversalChartView(
                        data: chartData,
                        metricName: viewModel.getCurrentMetricName(),
                        timeRange: viewModel.getCurrentTimeRangeText(),
                        configuration: metric.type.map { ChartConfiguration.forMetricType($0) }
                    )
                } else {
                    InsightsEmptyChartView(metricName: metric.name)
                }
            }
        }
    }
    
    private var metricSelectionPromptView: some View {
        VStack(spacing: CloveSpacing.large) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(CloveColors.accent.opacity(0.6))
            
            VStack(spacing: CloveSpacing.small) {
                Text("Explore Your Data")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Text("Select any metric to see detailed charts and trends over time")
                    .font(CloveFonts.body())
                    .foregroundStyle(CloveColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                showingMetricSelector = true
            } label: {
                HStack(spacing: CloveSpacing.small) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("Select Metric")
                        .font(CloveFonts.body())
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, CloveSpacing.large)
                .padding(.vertical, CloveSpacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .fill(
                            LinearGradient(
                                colors: [CloveColors.accent, CloveColors.accent.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: CloveColors.accent.opacity(0.3), radius: 6, x: 0, y: 3)
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CloveSpacing.xlarge)
    }
    
    // MARK: - Smart Insights Section
    
    private var smartInsightsSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.large) {
            HStack {
                Text("Smart Insights")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Spacer()
                
                NavigationLink(destination: SmartInsightsView()) {
                    HStack(spacing: CloveSpacing.xsmall) {
                        Text("View All")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                    }
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.accent)
                    .fontWeight(.semibold)
                }
            }
            
            SmartInsightsPreviewView()
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Foundation Preview Section
    
    private var foundationPreviewSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.large) {
            Text("Coming Soon")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(CloveColors.primaryText)
            
            VStack(spacing: CloveSpacing.medium) {
                InsightsFeaturePreviewCard(
                    icon: "chart.bar.xaxis",
                    title: "Correlation Analysis",
                    description: "Compare any two metrics to discover patterns and relationships in your health data"
                )
                
                InsightsFeaturePreviewCard(
                    icon: "brain.head.profile",
                    title: "Smart Insights",
                    description: "AI-powered analysis to identify trends, predict patterns, and provide personalized recommendations"
                )
                
                InsightsFeaturePreviewCard(
                    icon: "calendar.badge.clock",
                    title: "Advanced Time Controls",
                    description: "Custom date ranges, comparison modes, and seasonal pattern detection"
                )
            }
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(
                    LinearGradient(
                        colors: [CloveColors.accent.opacity(0.05), CloveColors.accent.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke(CloveColors.accent.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Supporting Views

struct InsightsTimePeriodChip: View {
    let period: TimePeriod
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(period.shortDisplayName)
                .font(CloveFonts.small())
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? .white : CloveColors.accent)
                .padding(.horizontal, CloveSpacing.medium)
                .padding(.vertical, CloveSpacing.small)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.full)
                        .fill(isSelected ? CloveColors.accent : CloveColors.accent.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: CloveCorners.full)
                                .stroke(CloveColors.accent.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct InsightsLoadingChartView: View {
    var body: some View {
        VStack(spacing: CloveSpacing.medium) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: CloveColors.accent))
                .scaleEffect(1.2)
            
            Text("Loading chart data...")
                .font(CloveFonts.body())
                .foregroundStyle(CloveColors.secondaryText)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
}

struct InsightsEmptyChartView: View {
    let metricName: String
    
    var body: some View {
        VStack(spacing: CloveSpacing.medium) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle")
                .font(.system(size: 40))
                .foregroundStyle(CloveColors.secondaryText.opacity(0.5))
            
            VStack(spacing: CloveSpacing.small) {
                Text("No data available")
                    .font(CloveFonts.body())
                    .foregroundStyle(CloveColors.primaryText)
                    .fontWeight(.medium)
                
                Text("Start logging \(metricName.lowercased()) to see trends")
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
}

struct InsightsFeaturePreviewCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: CloveSpacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(CloveColors.accent)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: CloveSpacing.small) {
                Text(title)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Text(description)
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
                    .lineLimit(3)
            }
            
            Spacer()
        }
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke(CloveColors.accent.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

#Preview {
    InsightsView()
}
