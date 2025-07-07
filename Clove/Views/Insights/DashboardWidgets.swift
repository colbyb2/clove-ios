import SwiftUI
import Charts

// MARK: - Metrics Overview Widget

struct TrendOverviewWidget: View {
    @State private var dashboardManager = DashboardManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.shared.accent)
                
                Text("Metrics Overview")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Spacer()
                
                Text("This Week")
                    .font(.system(.caption))
                    .foregroundStyle(CloveColors.secondaryText)
                    .padding(.horizontal, CloveSpacing.small)
                    .padding(.vertical, CloveSpacing.xsmall)
                    .background(
                        RoundedRectangle(cornerRadius: CloveCorners.small)
                            .fill(Theme.shared.accent.opacity(0.1))
                    )
            }
            
            if dashboardManager.metricSummaries.isEmpty {
                emptyStateView("No metrics data")
            } else {
                metricsGrid
            }
        }
        .padding(CloveSpacing.large)
    }
    
    private var metricsGrid: some View {
        HStack(spacing: CloveSpacing.large) {
            ForEach(Array(dashboardManager.metricSummaries.prefix(4).enumerated()), id: \.offset) { index, summary in
                VStack(spacing: CloveSpacing.small) {
                    Text(summary.icon)
                        .font(.system(size: 20))
                    
                    if let current = summary.currentValue {
                        Text(formatValue(current, for: summary.metric))
                            .font(.system(.callout, design: .rounded).weight(.bold))
                            .foregroundStyle(CloveColors.primaryText)
                    }
                    
                    HStack(spacing: CloveSpacing.xsmall) {
                        Image(systemName: summary.trend.icon)
                            .font(.system(size: 10))
                            .foregroundStyle(summary.trend.color)
                        
                        if summary.changePercentage > 0 {
                            Text("\(String(format: "%.0f", summary.changePercentage))%")
                                .font(.system(.caption2))
                                .foregroundStyle(summary.trend.color)
                        }
                    }
                    
                    Text(summary.metric.displayName)
                        .font(.system(.caption2))
                        .foregroundStyle(CloveColors.secondaryText)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    
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
    
    private func emptyStateView(_ message: String) -> some View {
        Text(message)
            .font(CloveFonts.body())
            .foregroundStyle(CloveColors.secondaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

// MARK: - Weekly Pattern Widget

struct WeeklyPatternWidget: View {
    @State private var dashboardManager = DashboardManager.shared
    
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.shared.accent)
                
                Text("Weekly Pattern")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Spacer()
            }
            
            if let firstPattern = dashboardManager.weeklyPatterns.first {
                VStack(spacing: CloveSpacing.small) {
                    Text(firstPattern.key)
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                    
                    HStack(spacing: CloveSpacing.small) {
                        ForEach(Array(firstPattern.value.enumerated()), id: \.offset) { index, value in
                            VStack(spacing: CloveSpacing.xsmall) {
                                RoundedRectangle(cornerRadius: 4)
                                  .fill(Theme.shared.accent.opacity(intensityOpacity(value, maxValue: firstPattern.value.max() ?? 1)))
                                    .frame(width: 20, height: 30)
                                
                                Text(weekdays[index])
                                    .font(.system(.caption2))
                                    .foregroundStyle(CloveColors.secondaryText)
                            }
                        }
                    }
                }
            } else {
                emptyStateView("No patterns detected")
            }
        }
        .padding(CloveSpacing.large)
    }
    
    private func intensityOpacity(_ value: Double, maxValue: Double) -> Double {
        guard maxValue > 0 else { return 0.1 }
        return max(0.1, min(1.0, value / maxValue))
    }
    
    private func emptyStateView(_ message: String) -> some View {
        Text(message)
            .font(CloveFonts.body())
            .foregroundStyle(CloveColors.secondaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

// MARK: - Correlation Highlight Widget

struct CorrelationHighlightWidget: View {
    @State private var dashboardManager = DashboardManager.shared
    
    var body: some View {
        VStack(spacing: CloveSpacing.medium) {
            HStack {
                Image(systemName: "link")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.shared.accent)
                
                Text("Top Correlation")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Spacer()
            }
            
            if let correlation = dashboardManager.topCorrelation {
                VStack(spacing: CloveSpacing.small) {
                    Text("\(String(format: "%.2f", abs(correlation.2)))")
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .foregroundStyle(correlationColor(correlation.2))
                    
                    Text("\(correlation.0) & \(correlation.1)")
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.primaryText)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                    
                    Text(correlationDescription(correlation.2))
                        .font(.system(.caption2))
                        .foregroundStyle(CloveColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
            } else {
                VStack(spacing: CloveSpacing.small) {
                    Text("--")
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .foregroundStyle(CloveColors.secondaryText)
                    
                    Text("No correlations found")
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(CloveSpacing.large)
    }
    
    private func correlationColor(_ correlation: Double) -> Color {
        let abs = abs(correlation)
        switch abs {
        case 0.7...1.0: return CloveColors.green
        case 0.4..<0.7: return Theme.shared.accent
        case 0.2..<0.4: return .orange
        default: return CloveColors.secondaryText
        }
    }
    
    private func correlationDescription(_ correlation: Double) -> String {
        let direction = correlation > 0 ? "Positive" : "Negative"
        let strength = abs(correlation)
        
        switch strength {
        case 0.7...1.0: return "\(direction) - Strong"
        case 0.4..<0.7: return "\(direction) - Moderate"
        case 0.2..<0.4: return "\(direction) - Weak"
        default: return "Very Weak"
        }
    }
}


// MARK: - Dashboard Customization View

struct DashboardCustomizationView: View {
    @State private var dashboardManager = DashboardManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            customizationContent
        }
    }
    
    private var customizationContent: some View {
        List {
            Section {
                ForEach(dashboardManager.widgets) { widget in
                    WidgetCustomizationRow(widget: widget)
                }
                .onMove { source, destination in
                    dashboardManager.reorderWidgets(from: source, to: destination)
                }
            } header: {
                Text("Widgets")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
            } footer: {
                Text("Toggle widgets on/off and reorder them by dragging. Changes are saved automatically.")
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Customize Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") {
                    dismiss()
                }
                .font(CloveFonts.body())
                .foregroundStyle(Theme.shared.accent)
                .fontWeight(.semibold)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
                    .font(CloveFonts.body())
                    .foregroundStyle(Theme.shared.accent)
            }
        }
    }
}

// MARK: - Widget Customization Row

struct WidgetCustomizationRow: View {
    let widget: DashboardWidget
    @State private var dashboardManager = DashboardManager.shared
    
    var body: some View {
        HStack(spacing: CloveSpacing.medium) {
            Image(systemName: widget.type.icon)
                .font(.system(size: 20))
                .foregroundStyle(widget.isEnabled ? Theme.shared.accent : CloveColors.secondaryText)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
                Text(widget.type.displayName)
                    .font(CloveFonts.body())
                    .foregroundStyle(widget.isEnabled ? CloveColors.primaryText : CloveColors.secondaryText)
                    .fontWeight(.medium)
                
                Text(widgetDescription(widget.type))
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { widget.isEnabled },
                set: { _ in dashboardManager.toggleWidget(widget.type) }
            ))
            .toggleStyle(SwitchToggleStyle(tint: Theme.shared.accent))
        }
        .padding(.vertical, CloveSpacing.xsmall)
    }
    
    private func widgetDescription(_ type: WidgetType) -> String {
        switch type {
        case .healthScore: return "Overall health score based on all metrics"
        case .streakCounter: return "Current streaks for good health days"
        case .recentInsights: return "Latest AI-generated health insights"
        case .trendOverview: return "Overview of key health metrics with trends"
        case .weeklyPattern: return "Weekly patterns in your health data"
        case .correlationHighlight: return "Strongest correlation between metrics"
        }
    }
}

#Preview {
    VStack(spacing: CloveSpacing.large) {
        HStack {
            HealthScoreWidget()
            StreakCounterWidget()
        }
        
        TrendOverviewWidget()
        
        HStack {
            WeeklyPatternWidget()
            CorrelationHighlightWidget()
        }
    }
    .padding()
    .background(CloveColors.background)
}
