import SwiftUI

struct InsightsView: View {
    @State private var viewModel = InsightsV2ViewModel()
    @State private var showingMetricSelector = false
    @State private var showingFullScreenChart = false
    
    // Insights customization settings
    @AppStorage(Constants.INSIGHTS_OVERVIEW_DASHBOARD) private var overviewDashboard: Bool = true
    @AppStorage(Constants.INSIGHTS_SMART_INSIGHTS) private var smartInsights: Bool = true
    @AppStorage(Constants.INSIGHTS_METRIC_CHARTS) private var metricCharts: Bool = true
    @AppStorage(Constants.INSIGHTS_CORRELATIONS) private var correlations: Bool = true
    
    // MARK: - Customization Prompt Section
    
    private var customizationPromptSection: some View {
        VStack(spacing: CloveSpacing.medium) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.shared.accent)
                
                VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
                    Text("Want More Insights?")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text("You can enable additional features anytime")
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                }
                
                Spacer()
            }
            
            NavigationLink(destination: InsightsCustomizationView()) {
                HStack(spacing: CloveSpacing.small) {
                    Image(systemName: "gear")
                        .font(.system(size: 14))
                    Text("Customize Insights")
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
                                colors: [Theme.shared.accent, Theme.shared.accent.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Theme.shared.accent.opacity(0.3), radius: 6, x: 0, y: 3)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(
                    LinearGradient(
                        colors: [Theme.shared.accent.opacity(0.05), Theme.shared.accent.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke(Theme.shared.accent.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: CloveSpacing.large) {
                // Overview Dashboard section
                if overviewDashboard {
                    overviewDashboardSection
                }
                
                // Time period selector header - always show as it's essential
                timePeriodSelectorSection
                
                // New metric exploration section
                if metricCharts {
                    metricExplorationSection
                }
                
                // Cross Reference section
                if correlations {
                    crossReferenceSection
                }
                
                // Smart Insights section
                if smartInsights {
                    smartInsightsSection
                }
                
                // Customization prompt if user has minimal features enabled
                if [overviewDashboard, metricCharts, smartInsights, correlations].filter({ $0 }).count <= 1 {
                    customizationPromptSection
                }
            }
            .padding(.horizontal, CloveSpacing.large)
            .padding(.bottom, CloveSpacing.xlarge)
            .padding(.top, CloveSpacing.medium)
        }
        .background(CloveColors.background.ignoresSafeArea())
        .navigationTitle("Health Insights")
        .navigationBarTitleDisplayMode(.inline)
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
                                    colors: [Theme.shared.accent, Theme.shared.accent.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Theme.shared.accent.opacity(0.3), radius: 4, x: 0, y: 2)
                    )
                }
            }
        }
        .sheet(isPresented: $showingMetricSelector) {
            MetricExplorer { metricId in
                Task {
                    await viewModel.selectMetric(id: metricId)
                }
            }
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            Task {
                await viewModel.refreshCurrentMetric()
            }
            if TutorialManager.shared.startTutorial(Tutorials.InsightsView) == .Failure {
                print("Tutorial [InsightsView] Failed to Start")
            }
        }
        .onChange(of: viewModel.timePeriodManager.selectedPeriod) { _, newPeriod in
            Task {
                await viewModel.timePeriodChanged()
            }
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
                                    Task {
                                        await viewModel.timePeriodChanged()
                                    }
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
                .foregroundStyle(Theme.shared.accent)
                .fontWeight(.semibold)
            }
            .padding(.horizontal)
            
            if let metric = viewModel.selectedMetric {
                VStack(spacing: 0) {
                    MetricChart(metric: metric)
                        .onTapGesture {
                            showingFullScreenChart = true
                        }

                    HStack {
                        Spacer()
                        Text("Tap to Expand")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(CloveColors.secondaryText.opacity(0.5))
                            .padding(.trailing, CloveSpacing.small)
                            .padding(.top, 4)
                    }
                }
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
        .fullScreenCover(isPresented: $showingFullScreenChart) {
            ExpandedChartView(
                metric: viewModel.selectedMetric,
                onClose: { showingFullScreenChart = false }
            )
        }
    }
    
    private func selectedMetricChartView() -> some View {
        VStack(spacing: CloveSpacing.medium) {
            // Metric info header
            if let selectedMetric = viewModel.selectedMetric {
                HStack {
                    Text(selectedMetric.icon)
                        .font(.system(size: 24))
                    
                    VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
                        Text(selectedMetric.displayName)
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundStyle(CloveColors.primaryText)
                        
                        Text(selectedMetric.description)
                            .font(CloveFonts.small())
                            .foregroundStyle(CloveColors.secondaryText)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                }
                
                // Chart display
                if viewModel.isLoadingMetricData {
                    InsightsLoadingChartView()
                } else if !viewModel.metricData.isEmpty {
                    viewModel.createChartView()
                } else {
                    InsightsEmptyChartView(metricName: selectedMetric.displayName)
                }
            }
        }
    }
    
    
    private var metricSelectionPromptView: some View {
        VStack(spacing: CloveSpacing.large) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(Theme.shared.accent.opacity(0.6))
            
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
                                colors: [Theme.shared.accent, Theme.shared.accent.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Theme.shared.accent.opacity(0.3), radius: 6, x: 0, y: 3)
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CloveSpacing.xlarge)
    }
    
    // MARK: - Overview Dashboard Section
    
    private var overviewDashboardSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.large) {
            HStack {
                Text("Overview Dashboard")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Spacer()
                
                NavigationLink(destination: OverviewDashboardView()) {
                    HStack(spacing: CloveSpacing.xsmall) {
                        Text("View All")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                    }
                    .font(CloveFonts.small())
                    .foregroundStyle(Theme.shared.accent)
                    .fontWeight(.semibold)
                }
            }
            
            OverviewDashboardPreviewView()
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Cross Reference Section
    
    private var crossReferenceSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.large) {
            HStack {
                Text("Cross Reference")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Spacer()
                
                NavigationLink(destination: CrossReferenceView()) {
                    HStack(spacing: CloveSpacing.xsmall) {
                        Text("View All")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                    }
                    .font(CloveFonts.small())
                    .foregroundStyle(Theme.shared.accent)
                    .fontWeight(.semibold)
                }
            }
            
            CrossReferencePreviewView()
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        )
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
                    .foregroundStyle(Theme.shared.accent)
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
                .foregroundStyle(isSelected ? .white : Theme.shared.accent)
                .padding(.horizontal, CloveSpacing.medium)
                .padding(.vertical, CloveSpacing.small)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.full)
                        .fill(isSelected ? Theme.shared.accent : Theme.shared.accent.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: CloveCorners.full)
                                .stroke(Theme.shared.accent.opacity(0.3), lineWidth: 1)
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
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.shared.accent))
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
                .foregroundStyle(Theme.shared.accent)
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
                        .stroke(Theme.shared.accent.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct CrossReferencePreviewView: View {
    var body: some View {
        VStack(spacing: CloveSpacing.medium) {
            HStack {
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    Text("Correlation Analysis")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text("Compare metrics to discover patterns")
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                }
                
                Spacer()
                
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.shared.accent)
            }
            
            // Sample correlation cards
            VStack(spacing: CloveSpacing.small) {
                correlationPreviewCard(
                    primary: "Mood",
                    secondary: "Energy",
                    correlation: 0.78,
                    strength: "Strong",
                    direction: "Positive"
                )
                
                correlationPreviewCard(
                    primary: "Weather",
                    secondary: "Bloating",
                    correlation: -0.65,
                    strength: "Moderate",
                    direction: "Negative"
                )
            }
            
            // Action button
            NavigationLink(destination: CrossReferenceView()) {
                HStack(spacing: CloveSpacing.small) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 14))
                    Text("Create Analysis")
                        .font(CloveFonts.small())
                        .fontWeight(.semibold)
                }
                .foregroundStyle(Theme.shared.accent)
                .padding(.horizontal, CloveSpacing.medium)
                .padding(.vertical, CloveSpacing.small)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .fill(Theme.shared.accent.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: CloveCorners.medium)
                                .stroke(Theme.shared.accent.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private func correlationPreviewCard(primary: String, secondary: String, correlation: Double, strength: String, direction: String) -> some View {
        HStack {
            HStack(spacing: CloveSpacing.xsmall) {
                Text(primary)
                    .font(CloveFonts.small())
                    .fontWeight(.medium)
                    .foregroundStyle(CloveColors.primaryText)
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundStyle(CloveColors.secondaryText)
                
                Text(secondary)
                    .font(CloveFonts.small())
                    .fontWeight(.medium)
                    .foregroundStyle(CloveColors.primaryText)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.2f", correlation))
                    .font(CloveFonts.small())
                    .fontWeight(.bold)
                    .foregroundStyle(correlation > 0 ? CloveColors.green : CloveColors.red)
                
                Text("\(strength)")
                    .font(.system(size: 10))
                    .foregroundStyle(CloveColors.secondaryText)
            }
        }
        .padding(.horizontal, CloveSpacing.medium)
        .padding(.vertical, CloveSpacing.small)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.small)
                .fill(CloveColors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.small)
                        .stroke(Theme.shared.accent.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct ExpandedChartView: View {
    let metric: (any MetricProvider)?
    let onClose: () -> Void
    
    var body: some View {
        ZStack {
            CloveColors.background.ignoresSafeArea()
            
            if let metric = metric {
                VStack(spacing: 0) {
                    HStack {
                        Text(metric.icon)
                            .font(.system(size: 26))
                        Text(metric.displayName)
                            .font(.system(.title2, design: .rounded).weight(.semibold))
                            .foregroundStyle(CloveColors.primaryText)
                        
                        Spacer()
                    }
                    .padding(5)
                    
                    MetricChart(metric: metric,
                                style: MetricChartStyle(primary: Theme.shared.accent, background: CloveColors.background, text: CloveColors.secondaryText),
                                config: MetricChartConfig(showAnnotation: true, showHeader: false, showFooter: false))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .overlay(
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: onClose) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(CloveColors.primaryText)
                                    .padding(8)
                                    .background(
                                        Circle()
                                            .fill(CloveColors.card)
                                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    )
                            }
                            .padding(.trailing, CloveSpacing.large)
                            .padding(.vertical, CloveSpacing.small)
                        }
                        Spacer()
                    }
                )
            }
        }
    }
}

#Preview {
    InsightsView()
}
