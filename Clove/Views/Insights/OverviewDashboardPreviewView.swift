import SwiftUI

// MARK: - Overview Dashboard Preview View

struct OverviewDashboardPreviewView: View {
    @State private var dashboardManager = DashboardManager.shared
    @State private var isLoaded = false
    
    private let columns = [
        GridItem(.flexible(), spacing: CloveSpacing.small),
        GridItem(.flexible(), spacing: CloveSpacing.small)
    ]
    
    var body: some View {
        VStack(spacing: CloveSpacing.medium) {
            if dashboardManager.isLoading {
                loadingView
            } else if previewWidgets.isEmpty {
                emptyView
            } else {
                dashboardPreview
            }
        }
        .onAppear {
            loadDashboardIfNeeded()
        }
    }
    
    private var previewWidgets: [DashboardWidget] {
        let enabledWidgets = dashboardManager.widgets.filter { $0.isEnabled }
        return Array(enabledWidgets.prefix(4)) // Show top 4 widgets
    }
    
    private var loadingView: some View {
        HStack(spacing: CloveSpacing.medium) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: CloveColors.accent))
                .scaleEffect(0.8)
            
            Text("Loading dashboard...")
                .font(CloveFonts.body())
                .foregroundStyle(CloveColors.secondaryText)
            
            Spacer()
        }
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.background)
        )
    }
    
    private var emptyView: some View {
        VStack(spacing: CloveSpacing.small) {
            HStack(spacing: CloveSpacing.medium) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 20))
                    .foregroundStyle(CloveColors.accent.opacity(0.6))
                
                VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
                    Text("Dashboard ready")
                        .font(CloveFonts.body())
                        .foregroundStyle(CloveColors.primaryText)
                        .fontWeight(.medium)
                    
                    Text("View personalized health widgets")
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                }
                
                Spacer()
            }
        }
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.background)
        )
    }
    
    private var dashboardPreview: some View {
        LazyVGrid(columns: columns, spacing: CloveSpacing.small) {
            ForEach(previewWidgets) { widget in
                PreviewWidgetCard(widget: widget)
            }
        }
    }
    
    private func loadDashboardIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true
        
        Task {
            await dashboardManager.refreshDashboard()
        }
    }
}

// MARK: - Preview Widget Card

struct PreviewWidgetCard: View {
    let widget: DashboardWidget
    @State private var dashboardManager = DashboardManager.shared
    
    var body: some View {
        VStack(spacing: CloveSpacing.small) {
            // Widget header
            HStack {
                Image(systemName: widget.type.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(CloveColors.accent)
                
                Text(widget.type.displayName)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Spacer()
            }
            
            // Widget content preview
            Group {
                switch widget.type {
                case .healthScore:
                    healthScorePreview
                case .streakCounter:
                    streakCounterPreview
                case .recentInsights:
                    insightsPreview
                case .trendOverview:
                    trendOverviewPreview
                case .weeklyPattern:
                    weeklyPatternPreview
                case .correlationHighlight:
                    correlationPreview
                }
            }
        }
        .padding(CloveSpacing.small)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.small)
                .fill(CloveColors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.small)
                        .stroke(CloveColors.accent.opacity(0.1), lineWidth: 1)
                )
        )
        .frame(height: 80)
    }
    
    // MARK: - Widget Previews
    
    private var healthScorePreview: some View {
        VStack(spacing: CloveSpacing.xsmall) {
            if let healthScore = dashboardManager.healthScore {
                Text("\(Int(healthScore.overallScore))")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(getScoreColor(healthScore.overallScore))
                
                Text("Health Score")
                    .font(.system(.caption2))
                    .foregroundStyle(CloveColors.secondaryText)
            } else {
                Text("--")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(CloveColors.secondaryText)
                
                Text("Calculating...")
                    .font(.system(.caption2))
                    .foregroundStyle(CloveColors.secondaryText)
            }
        }
    }
    
    
    private var streakCounterPreview: some View {
        VStack(spacing: CloveSpacing.xsmall) {
            if let streak = dashboardManager.currentStreaks.first {
                Text("\(streak.currentStreak)")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(streak.isActive ? .orange : CloveColors.secondaryText)
                
                Text("Day Streak")
                    .font(.system(.caption2))
                    .foregroundStyle(CloveColors.secondaryText)
            } else {
                Text("0")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(CloveColors.secondaryText)
                
                Text("No streaks")
                    .font(.system(.caption2))
                    .foregroundStyle(CloveColors.secondaryText)
            }
        }
    }
    
    private var insightsPreview: some View {
        VStack(spacing: CloveSpacing.xsmall) {
            if let insight = dashboardManager.topInsights.first {
                Image(systemName: insight.typeIcon)
                    .font(.system(size: 16))
                    .foregroundStyle(priorityColor(insight.priority))
                
                Text(insight.title)
                    .font(.system(.caption2))
                    .foregroundStyle(CloveColors.primaryText)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            } else {
                Text("💡")
                    .font(.system(size: 16))
                
                Text("No insights yet")
                    .font(.system(.caption2))
                    .foregroundStyle(CloveColors.secondaryText)
            }
        }
    }
    
    private var trendOverviewPreview: some View {
        VStack(spacing: CloveSpacing.xsmall) {
            HStack(spacing: CloveSpacing.xsmall) {
                ForEach(Array(dashboardManager.metricSummaries.prefix(3).enumerated()), id: \.offset) { _, summary in
                    VStack {
                        Text(summary.icon)
                            .font(.system(size: 8))
                        Image(systemName: summary.trend.icon)
                            .font(.system(size: 6))
                            .foregroundStyle(summary.trend.color)
                    }
                }
            }
            
            Text("Metrics")
                .font(.system(.caption2))
                .foregroundStyle(CloveColors.secondaryText)
        }
    }
    
    private var weeklyPatternPreview: some View {
        VStack(spacing: CloveSpacing.xsmall) {
            if let pattern = dashboardManager.weeklyPatterns.first {
                HStack(spacing: 2) {
                    ForEach(Array(pattern.value.prefix(7).enumerated()), id: \.offset) { _, value in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(CloveColors.accent.opacity(min(1.0, max(0.1, value / 10.0))))
                            .frame(width: 6, height: 12)
                    }
                }
                
                Text("Pattern")
                    .font(.system(.caption2))
                    .foregroundStyle(CloveColors.secondaryText)
            } else {
                Text("📊")
                    .font(.system(size: 16))
                
                Text("No patterns")
                    .font(.system(.caption2))
                    .foregroundStyle(CloveColors.secondaryText)
            }
        }
    }
    
    private var correlationPreview: some View {
        VStack(spacing: CloveSpacing.xsmall) {
            if let correlation = dashboardManager.topCorrelation {
                Text("\(String(format: "%.2f", abs(correlation.2)))")
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .foregroundStyle(correlationColor(correlation.2))
                
                Text("Correlation")
                    .font(.system(.caption2))
                    .foregroundStyle(CloveColors.secondaryText)
            } else {
                Text("🔗")
                    .font(.system(size: 16))
                
                Text("No correlations")
                    .font(.system(.caption2))
                    .foregroundStyle(CloveColors.secondaryText)
            }
        }
    }
    
    
    // MARK: - Helper Methods
    
    private func formatValue(_ value: Double, for metric: MetricType) -> String {
        switch metric {
        case .mood, .painLevel, .energyLevel:
            return String(format: "%.1f", value)
        case .medicationAdherence:
            return String(format: "%.0f%%", value)
        default:
            return String(format: "%.0f", value)
        }
    }
    
    private func getScoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return CloveColors.green
        case 60..<80: return CloveColors.accent
        case 40..<60: return .orange
        default: return CloveColors.red
        }
    }
    
    private func priorityColor(_ priority: InsightPriority) -> Color {
        switch priority {
        case .low: return CloveColors.blue
        case .medium: return CloveColors.accent
        case .high: return .orange
        case .critical: return CloveColors.red
        }
    }
    
    private func correlationColor(_ correlation: Double) -> Color {
        let abs = abs(correlation)
        switch abs {
        case 0.7...1.0: return CloveColors.green
        case 0.4..<0.7: return CloveColors.accent
        case 0.2..<0.4: return .orange
        default: return CloveColors.secondaryText
        }
    }
}

#Preview {
    VStack(spacing: CloveSpacing.large) {
        OverviewDashboardPreviewView()
        
        // Preview with sample widgets
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: CloveSpacing.small),
            GridItem(.flexible(), spacing: CloveSpacing.small)
        ], spacing: CloveSpacing.small) {
            PreviewWidgetCard(widget: DashboardWidget(type: .healthScore))
            PreviewWidgetCard(widget: DashboardWidget(type: .streakCounter))
            PreviewWidgetCard(widget: DashboardWidget(type: .recentInsights))
        }
    }
    .padding()
    .background(CloveColors.background)
}
