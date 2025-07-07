import SwiftUI

// MARK: - Smart Insights Preview View

struct SmartInsightsPreviewView: View {
    @State private var insightsEngine = InsightsEngine.shared
    @State private var isLoaded = false
    
    var body: some View {
        VStack(spacing: CloveSpacing.medium) {
            if insightsEngine.isGeneratingInsights {
                loadingView
            } else if previewInsights.isEmpty {
                emptyView
            } else {
                insightsPreview
            }
        }
        .onAppear {
            loadInsightsIfNeeded()
        }
    }
    
    private var previewInsights: [HealthInsight] {
        let allInsights = insightsEngine.currentInsights
        let highPriority = allInsights.filter { $0.priority == .high || $0.priority == .critical }
        let actionable = allInsights.filter { $0.isActionable }
        
        // Prioritize high priority and actionable insights
        let prioritized = Array(Set(highPriority + actionable))
        return Array(prioritized.prefix(3))
    }
    
    private var loadingView: some View {
        HStack(spacing: CloveSpacing.medium) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.shared.accent))
                .scaleEffect(0.8)
            
            Text("Analyzing your data...")
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
                Image(systemName: "lightbulb")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.shared.accent.opacity(0.6))
                
                VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
                    Text("No insights yet")
                        .font(CloveFonts.body())
                        .foregroundStyle(CloveColors.primaryText)
                        .fontWeight(.medium)
                    
                    Text("Keep logging to unlock personalized insights")
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
    
    private var insightsPreview: some View {
        VStack(spacing: CloveSpacing.small) {
            ForEach(previewInsights) { insight in
                InsightPreviewCard(insight: insight)
            }
            
            if insightsEngine.currentInsights.count > 3 {
                moreInsightsIndicator
            }
        }
    }
    
    private var moreInsightsIndicator: some View {
        HStack(spacing: CloveSpacing.small) {
            Text("+\(insightsEngine.currentInsights.count - 3) more insights")
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundStyle(CloveColors.secondaryText)
        }
        .padding(.horizontal, CloveSpacing.medium)
        .padding(.vertical, CloveSpacing.small)
    }
    
    private func loadInsightsIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true
        
        Task {
            await insightsEngine.generateInsights()
        }
    }
}

// MARK: - Insight Preview Card

struct InsightPreviewCard: View {
    let insight: HealthInsight
    
    var body: some View {
        HStack(spacing: CloveSpacing.medium) {
            // Priority and type indicator
            VStack(spacing: CloveSpacing.xsmall) {
                priorityIndicator
                
                Image(systemName: insight.typeIcon)
                    .font(.system(size: 12))
                    .foregroundStyle(CloveColors.secondaryText)
            }
            
            // Content
            VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
                Text(insight.title)
                    .font(CloveFonts.body())
                    .foregroundStyle(CloveColors.primaryText)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Text(insight.description)
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Actionable indicator
            if insight.isActionable {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.shared.accent)
            }
        }
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(priorityBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke(priorityBorderColor, lineWidth: 1)
                )
        )
    }
    
    private var priorityIndicator: some View {
        Circle()
            .fill(priorityColor)
            .frame(width: 6, height: 6)
    }
    
    private var priorityColor: Color {
        switch insight.priority {
        case .low: return CloveColors.blue
        case .medium: return Theme.shared.accent
        case .high: return .orange
        case .critical: return CloveColors.red
        }
    }
    
    private var priorityBackgroundColor: Color {
        priorityColor.opacity(0.05)
    }
    
    private var priorityBorderColor: Color {
        priorityColor.opacity(0.15)
    }
}

#Preview {
    VStack(spacing: CloveSpacing.large) {
        SmartInsightsPreviewView()
        
        // Preview with sample insights
        let sampleInsights = [
            HealthInsight(
                type: .achievement,
                priority: .high,
                title: "7-day mood streak!",
                description: "You've maintained excellent mood levels for a full week.",
                actionableText: "Keep up the great work!",
                confidence: 0.95,
                relevancePeriod: DateInterval(start: Date().addingTimeInterval(-7*24*60*60), end: Date()),
                associatedMetrics: ["Mood"],
                generatedAt: Date(),
                isActionable: true
            ),
            HealthInsight(
                type: .pattern,
                priority: .medium,
                title: "Weekly energy pattern detected",
                description: "Your energy levels tend to be highest on Mondays and lowest on Fridays.",
                actionableText: "Schedule important tasks for early in the week.",
                confidence: 0.7,
                relevancePeriod: DateInterval(start: Date().addingTimeInterval(-30*24*60*60), end: Date()),
                associatedMetrics: ["Energy Level"],
                generatedAt: Date(),
                isActionable: true
            )
        ]
        
        VStack(spacing: CloveSpacing.small) {
            ForEach(sampleInsights) { insight in
                InsightPreviewCard(insight: insight)
            }
        }
    }
    .padding()
    .background(CloveColors.background)
}
