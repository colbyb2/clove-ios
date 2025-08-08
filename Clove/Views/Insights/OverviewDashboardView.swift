import SwiftUI

// MARK: - Overview Dashboard View

struct OverviewDashboardView: View {
    @State private var dashboardManager = DashboardManager.shared
    @State private var showingCustomization = false
    
    // Remove the fixed column layout - we'll use a more flexible approach
    
    var body: some View {
        NavigationView {
            mainContent
        }
        .onAppear {
            loadDashboard()
        }
        .refreshable {
            await refreshDashboard()
        }
        .sheet(isPresented: $showingCustomization) {
            DashboardCustomizationView()
        }
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: CloveSpacing.large) {
                headerSection
                
                if dashboardManager.isLoading {
                    loadingSection
                } else {
                    widgetGrid
                }
            }
            .padding(.horizontal, CloveSpacing.large)
            .padding(.bottom, CloveSpacing.xlarge)
        }
        .background(CloveColors.background.ignoresSafeArea())
        .navigationTitle("Overview")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                customizeButton
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            HStack {
                VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
                    Text("Health Overview")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text("Your personalized health dashboard")
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                }
                
                Spacer()
                
                if let lastRefresh = dashboardManager.lastRefreshTime {
                    VStack(alignment: .trailing, spacing: CloveSpacing.xsmall) {
                        Text("Updated")
                            .font(CloveFonts.small())
                            .foregroundStyle(CloveColors.secondaryText)
                        
                        Text(lastRefresh.formatted(date: .omitted, time: .shortened))
                            .font(CloveFonts.small())
                            .foregroundStyle(Theme.shared.accent)
                            .fontWeight(.medium)
                    }
                }
            }
            
            // Quick stats
            if !dashboardManager.metricSummaries.isEmpty {
                quickStatsBar
            }
        }
        .padding(CloveSpacing.large)
        .background(cardBackground)
    }
    
    private var quickStatsBar: some View {
        HStack(spacing: CloveSpacing.large) {
            ForEach(Array(dashboardManager.metricSummaries.prefix(3).enumerated()), id: \.offset) { _, summary in
                QuickStatItem(summary: summary)
            }
            Spacer()
        }
    }
    
    // MARK: - Widget Layout
    
    private var widgetGrid: some View {
        VStack(spacing: CloveSpacing.medium) {
            // Row 1: Health Score and Streak (small widgets side by side)
            if hasWidget(.healthScore) || hasWidget(.streakCounter) {
                HStack(spacing: CloveSpacing.medium) {
                    if hasWidget(.healthScore) {
                        WidgetContainer(widget: getWidget(.healthScore)!)
                            .frame(maxWidth: .infinity)
                    }
                    if hasWidget(.streakCounter) {
                        WidgetContainer(widget: getWidget(.streakCounter)!)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            
            
            // Row 3: Recent Insights and Correlation (side by side if both present)
            if hasWidget(.recentInsights) || hasWidget(.correlationHighlight) {
                HStack(spacing: CloveSpacing.medium) {
                    if hasWidget(.recentInsights) {
                        WidgetContainer(widget: getWidget(.recentInsights)!)
                            .frame(maxWidth: .infinity)
                    }
                    if hasWidget(.correlationHighlight) {
                        WidgetContainer(widget: getWidget(.correlationHighlight)!)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            
            // Row 2: Metrics Overview (full width)
            if hasWidget(.trendOverview) {
                WidgetContainer(widget: getWidget(.trendOverview)!)
            }
            
            // Row 4: Weekly Pattern (full width)
            if hasWidget(.weeklyPattern) {
                WidgetContainer(widget: getWidget(.weeklyPattern)!)
            }
        }
    }
    
    // MARK: - Widget Helper Methods
    
    private func hasWidget(_ type: WidgetType) -> Bool {
        enabledWidgets.contains { $0.type == type }
    }
    
    private func getWidget(_ type: WidgetType) -> DashboardWidget? {
        enabledWidgets.first { $0.type == type }
    }
    
    private var enabledWidgets: [DashboardWidget] {
        dashboardManager.widgets.filter { $0.isEnabled }
    }
    
    // MARK: - Loading Section
    
    private var loadingSection: some View {
        VStack(spacing: CloveSpacing.medium) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.shared.accent))
                .scaleEffect(1.2)
            
            Text("Loading dashboard...")
                .font(CloveFonts.body())
                .foregroundStyle(CloveColors.secondaryText)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
    }
    
    // MARK: - Customize Button
    
    private var customizeButton: some View {
        Button {
            showingCustomization = true
        } label: {
            HStack(spacing: CloveSpacing.xsmall) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16))
                Text("Customize")
                    .font(CloveFonts.small())
                    .fontWeight(.semibold)
            }
            .foregroundStyle(Theme.shared.accent)
        }
    }
    
    // MARK: - Helper Views
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: CloveCorners.medium)
            .fill(CloveColors.card)
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Helper Methods
    
    private func loadDashboard() {
        Task {
            await dashboardManager.refreshDashboard()
        }
    }
    
    private func refreshDashboard() async {
        await dashboardManager.refreshDashboard()
    }
}

// MARK: - Quick Stat Item

struct QuickStatItem: View {
    let summary: MetricSummaryData
    
    var body: some View {
        VStack(spacing: CloveSpacing.xsmall) {
            HStack(spacing: CloveSpacing.small) {
                Text(summary.metric.icon)
                    .font(.system(size: 16))
                
                Image(systemName: summary.trend.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(summary.trend.color)
            }
            
            if let current = summary.currentValue {
                Text(formatValue(current, for: summary.metric))
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(CloveColors.primaryText)
            }
            
            Text(summary.metric.displayName)
                .font(.system(.caption2))
                .foregroundStyle(CloveColors.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func formatValue(_ value: Double, for metric: MetricType) -> String {
        switch metric {
        case .mood, .painLevel, .energyLevel:
            return String(format: "%.1f", value)
        case .medicationAdherence:
            return String(format: "%.0f%%", value)
        case .weather:
            return convertNumericToWeather(value)
        default:
            return String(format: "%.0f", value)
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
}

// MARK: - Widget Container

struct WidgetContainer: View {
    let widget: DashboardWidget
    @State private var dashboardManager = DashboardManager.shared
    
    var body: some View {
        Group {
            switch widget.type {
            case .healthScore:
                HealthScoreWidget()
            case .streakCounter:
                StreakCounterWidget()
            case .recentInsights:
                RecentInsightsWidget()
            case .trendOverview:
                TrendOverviewWidget()
            case .weeklyPattern:
                WeeklyPatternWidget()
            case .correlationHighlight:
                CorrelationHighlightWidget()
            }
        }
        .frame(minHeight: minHeightForWidget(widget.type))
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CloveCorners.medium))
    }
    
    private func minHeightForWidget(_ type: WidgetType) -> CGFloat {
        switch type {
        case .healthScore, .streakCounter, .correlationHighlight:
            return 140
        case .recentInsights, .weeklyPattern:
            return 160
        case .trendOverview:
            return 200
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: CloveCorners.medium)
            .fill(CloveColors.card)
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Health Score Widget

struct HealthScoreWidget: View {
    @State private var dashboardManager = DashboardManager.shared
    @State private var showingInfo = false
    
    var body: some View {
        ZStack {
           VStack(spacing: CloveSpacing.medium) {
               HStack {
                   Image(systemName: "heart.fill")
                       .font(.system(size: 18))
                       .foregroundStyle(CloveColors.red)
                   
                   Text("Health Score")
                       .font(.system(.subheadline, design: .rounded).weight(.semibold))
                       .foregroundStyle(CloveColors.primaryText)
                   
                   Spacer()
                   
                   if let healthScore = dashboardManager.healthScore {
                       Image(systemName: getTrendIcon(healthScore.trend))
                           .font(.system(size: 14))
                           .foregroundStyle(getTrendColor(healthScore.trend))
                   }
               }
               
               if let healthScore = dashboardManager.healthScore {
                   VStack(spacing: CloveSpacing.small) {
                       Text("\(Int(healthScore.overallScore))")
                           .font(.system(.largeTitle, design: .rounded).weight(.bold))
                           .foregroundStyle(getScoreColor(healthScore.overallScore))
                       
                       Text("out of 100")
                           .font(CloveFonts.small())
                           .foregroundStyle(CloveColors.secondaryText)
                       
                       ProgressView(value: healthScore.overallScore, total: 100)
                           .progressViewStyle(LinearProgressViewStyle(tint: getScoreColor(healthScore.overallScore)))
                           .frame(height: 6)
                   }
               } else {
                   VStack(spacing: CloveSpacing.small) {
                       Text("--")
                           .font(.system(.largeTitle, design: .rounded).weight(.bold))
                           .foregroundStyle(CloveColors.secondaryText)
                       
                       Text("Calculating...")
                           .font(CloveFonts.small())
                           .foregroundStyle(CloveColors.secondaryText)
                   }
               }
           }
           .padding(CloveSpacing.large)
           
           VStack {
              HStack {
                 Spacer()
                 Button {
                     showingInfo = true
                 } label: {
                     Image(systemName: "info.circle")
                         .font(.system(size: 14))
                         .foregroundStyle(CloveColors.secondaryText)
                 }
              }
              Spacer()
           }
           .padding(CloveSpacing.small)
        }
        .onTapGesture {
            showingInfo = true
        }
        .sheet(isPresented: $showingInfo) {
            HealthScoreInfoView()
        }
    }
    
    private func getTrendIcon(_ trend: HealthScoreData.TrendDirection) -> String {
        switch trend {
        case .improving: return "arrow.up"
        case .declining: return "arrow.down"
        case .stable: return "minus"
        }
    }
    
    private func getTrendColor(_ trend: HealthScoreData.TrendDirection) -> Color {
        trend.color
    }
    
    private func getScoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return CloveColors.green
        case 60..<80: return Theme.shared.accent
        case 40..<60: return .orange
        default: return CloveColors.red
        }
    }
}

// MARK: - Health Score Info View

struct HealthScoreInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: CloveSpacing.large) {
                    // Header
                    VStack(alignment: .leading, spacing: CloveSpacing.medium) {
                        HStack {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(CloveColors.red)
                            
                            Text("Health Score")
                                .font(.system(.title2, design: .rounded).weight(.bold))
                                .foregroundStyle(CloveColors.primaryText)
                        }
                        
                        Text("Your personalized health rating from 0-100")
                            .font(CloveFonts.body())
                            .foregroundStyle(CloveColors.secondaryText)
                    }
                    
                    // What it is
                    infoSection(
                        title: "What is the Health Score?",
                        content: "Your Health Score is a single number (0-100) that summarizes how you've been feeling overall. Think of it like a report card for your health - the higher the number, the better you've been doing with managing your symptoms and well-being."
                    )
                    
                    // How it's calculated
                    infoSection(
                        title: "How is it calculated?",
                        content: "The app looks at all the health metrics you track - like mood, pain levels, energy, and medication adherence. Each metric gets converted to a 0-100 scale, then they're combined using a weighted average. More important metrics (like severe symptoms) have a bigger impact on your overall score."
                    )
                    
                    // Score ranges
                    VStack(alignment: .leading, spacing: CloveSpacing.medium) {
                        Text("Score Ranges")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(CloveColors.primaryText)
                        
                        VStack(spacing: CloveSpacing.small) {
                            scoreRangeRow(range: "80-100", description: "Excellent - You're managing well", color: CloveColors.green)
                            scoreRangeRow(range: "60-79", description: "Good - On the right track", color: Theme.shared.accent)
                            scoreRangeRow(range: "40-59", description: "Fair - Some challenges", color: .orange)
                            scoreRangeRow(range: "0-39", description: "Needs attention - Consider reaching out for support", color: CloveColors.red)
                        }
                    }
                    
                    // Trends
                    infoSection(
                        title: "Understanding Trends",
                        content: "The arrow next to your score shows whether your health has been improving ↗, declining ↘, or staying stable → compared to recent weeks. Small changes are normal - focus on the overall pattern over time."
                    )
                    
                    // Important note
                    VStack(alignment: .leading, spacing: CloveSpacing.small) {
                        Text("Important Reminder")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(CloveColors.primaryText)
                        
                        Text("This score is a helpful tool for tracking patterns, but it doesn't replace professional medical advice. Always consult with your healthcare team for medical decisions.")
                            .font(CloveFonts.body())
                            .foregroundStyle(CloveColors.secondaryText)
                            .padding(CloveSpacing.medium)
                            .background(
                                RoundedRectangle(cornerRadius: CloveCorners.medium)
                                    .fill(Theme.shared.accent.opacity(0.1))
                            )
                    }
                }
                .padding(CloveSpacing.large)
            }
            .navigationTitle("Health Score Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(CloveFonts.body())
                    .foregroundStyle(Theme.shared.accent)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func infoSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(CloveColors.primaryText)
            
            Text(content)
                .font(CloveFonts.body())
                .foregroundStyle(CloveColors.secondaryText)
                .lineSpacing(2)
        }
    }
    
    private func scoreRangeRow(range: String, description: String, color: Color) -> some View {
        HStack(spacing: CloveSpacing.medium) {
            Text(range)
                .font(.system(.callout, design: .rounded).weight(.bold))
                .foregroundStyle(color)
                .frame(width: 60, alignment: .leading)
            
            Text(description)
                .font(CloveFonts.body())
                .foregroundStyle(CloveColors.secondaryText)
            
            Spacer()
        }
        .padding(.vertical, CloveSpacing.xsmall)
    }
}

// MARK: - Streak Counter Widget

struct StreakCounterWidget: View {
    @State private var dashboardManager = DashboardManager.shared
    
    var body: some View {
        VStack(spacing: CloveSpacing.medium) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.orange)
                
                Text("Streak")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Spacer()
            }
            
            if let bestStreak = dashboardManager.currentStreaks.first {
                VStack(spacing: CloveSpacing.small) {
                    Text("\(bestStreak.currentStreak)")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(bestStreak.isActive ? .orange : CloveColors.secondaryText)
                    
                    Text(bestStreak.streakType)
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                        .multilineTextAlignment(.center)
                    
                    if bestStreak.longestStreak > bestStreak.currentStreak {
                        Text("Best: \(bestStreak.longestStreak)")
                            .font(.system(.caption2))
                            .foregroundStyle(CloveColors.secondaryText.opacity(0.7))
                    }
                }
            } else {
                VStack(spacing: CloveSpacing.small) {
                    Text("0")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(CloveColors.secondaryText)
                    
                    Text("Start logging to build streaks")
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(CloveSpacing.large)
    }
}

// MARK: - Recent Insights Widget

struct RecentInsightsWidget: View {
    @State private var dashboardManager = DashboardManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.shared.accent)
                
                Text("Insights")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Spacer()
                
                NavigationLink(destination: SmartInsightsView()) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(CloveColors.secondaryText)
                }
            }
            
            if dashboardManager.topInsights.isEmpty {
                emptyStateView("No insights yet")
            } else {
                VStack(spacing: CloveSpacing.small) {
                    ForEach(Array(dashboardManager.topInsights.prefix(2).enumerated()), id: \.offset) { _, insight in
                        InsightPreviewRow(insight: insight)
                    }
                }
            }
        }
        .padding(CloveSpacing.large)
    }
    
    private func emptyStateView(_ message: String) -> some View {
        Text(message)
            .font(CloveFonts.body())
            .foregroundStyle(CloveColors.secondaryText)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Insight Preview Row

struct InsightPreviewRow: View {
    let insight: HealthInsight
    
    var body: some View {
        HStack(alignment: .top, spacing: CloveSpacing.small) {
            Image(systemName: insight.typeIcon)
                .font(.system(size: 12))
                .foregroundStyle(priorityColor)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.primaryText)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Text(insight.description)
                    .font(.system(.caption2))
                    .foregroundStyle(CloveColors.secondaryText)
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
    
    private var priorityColor: Color {
        switch insight.priority {
        case .low: return CloveColors.blue
        case .medium: return Theme.shared.accent
        case .high: return .orange
        case .critical: return CloveColors.red
        }
    }
}

#Preview {
    OverviewDashboardView()
}
