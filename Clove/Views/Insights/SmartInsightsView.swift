import SwiftUI

// MARK: - Smart Insights View

struct SmartInsightsView: View {
    @State private var insightsEngine = InsightsEngine.shared
    @State private var selectedInsightType: InsightType? = nil
    @State private var showingFilterSheet = false
    
    var body: some View {
        NavigationView {
            mainContent
        }
        .onAppear {
            loadInsights()
        }
        .refreshable {
            await refreshInsights()
        }
        .sheet(isPresented: $showingFilterSheet) {
            InsightFilterView(selectedType: $selectedInsightType)
        }
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: CloveSpacing.large) {
                headerSection
                
                if insightsEngine.isGeneratingInsights {
                    loadingSection
                } else if filteredInsights.isEmpty {
                    emptyStateSection
                } else {
                    insightsListSection
                }
            }
            .padding(.horizontal, CloveSpacing.large)
            .padding(.bottom, CloveSpacing.xlarge)
        }
        .background(CloveColors.background.ignoresSafeArea())
        .navigationTitle("Smart Insights")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                filterButton
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.shared.accent)
                
                VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
                    Text("AI-Powered Insights")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text("Personalized analysis of your health patterns")
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                }
                
                Spacer()
            }
            
            if let lastGeneration = insightsEngine.lastGenerationTime {
                HStack(spacing: CloveSpacing.small) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.shared.accent)
                    
                    Text("Last updated: \(lastGeneration.formatted(date: .omitted, time: .shortened))")
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                }
            }
            
            // Insights summary
            insightsSummary
        }
        .padding(CloveSpacing.large)
        .background(cardBackground)
    }
    
    private var insightsSummary: some View {
        HStack(spacing: CloveSpacing.large) {
            InsightSummaryBadge(
                count: insightsEngine.getHighPriorityInsights().count,
                label: "High Priority",
                color: CloveColors.red
            )
            
            InsightSummaryBadge(
                count: insightsEngine.getActionableInsights().count,
                label: "Actionable",
                color: Theme.shared.accent
            )
            
            InsightSummaryBadge(
                count: insightsEngine.currentInsights.count,
                label: "Total",
                color: CloveColors.secondaryText
            )
            
            Spacer()
        }
    }
    
    // MARK: - Filter Button
    
    private var filterButton: some View {
        Button {
            showingFilterSheet = true
        } label: {
            HStack(spacing: CloveSpacing.xsmall) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 16))
                Text("Filter")
                    .font(CloveFonts.small())
                    .fontWeight(.semibold)
            }
            .foregroundStyle(Theme.shared.accent)
        }
    }
    
    // MARK: - Insights List Section
    
    private var insightsListSection: some View {
        LazyVStack(spacing: CloveSpacing.medium) {
            ForEach(groupedInsights, id: \.key) { group in
                InsightGroupView(
                    type: group.key,
                    insights: group.value
                )
            }
        }
    }
    
    private var groupedInsights: [(key: InsightType, value: [HealthInsight])] {
        let grouped = Dictionary(grouping: filteredInsights) { $0.type }
        return grouped.sorted { first, second in
            let firstPriority = first.value.map { $0.priority.rawValue }.max() ?? 0
            let secondPriority = second.value.map { $0.priority.rawValue }.max() ?? 0
            return firstPriority > secondPriority
        }
    }
    
    private var filteredInsights: [HealthInsight] {
        if let selectedType = selectedInsightType {
            return insightsEngine.getInsights(ofType: selectedType)
        }
        return insightsEngine.currentInsights
    }
    
    // MARK: - Loading Section
    
    private var loadingSection: some View {
        VStack(spacing: CloveSpacing.medium) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.shared.accent))
                .scaleEffect(1.2)
            
            Text("Analyzing your health data...")
                .font(CloveFonts.body())
                .foregroundStyle(CloveColors.secondaryText)
            
            Text("This may take a moment")
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText.opacity(0.7))
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
    }
    
    // MARK: - Empty State Section
    
    private var emptyStateSection: some View {
        VStack(spacing: CloveSpacing.large) {
            Image(systemName: "lightbulb")
                .font(.system(size: 48))
                .foregroundStyle(Theme.shared.accent.opacity(0.6))
            
            VStack(spacing: CloveSpacing.small) {
                Text("No insights available")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Text("Start logging your health data regularly to receive personalized insights and recommendations")
                    .font(CloveFonts.body())
                    .foregroundStyle(CloveColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                Task {
                    await refreshInsights()
                }
            } label: {
                HStack(spacing: CloveSpacing.small) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16))
                    Text("Refresh Analysis")
                        .font(CloveFonts.body())
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, CloveSpacing.large)
                .padding(.vertical, CloveSpacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .fill(Theme.shared.accent)
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CloveSpacing.xlarge)
        .background(cardBackground)
    }
    
    // MARK: - Helper Views
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: CloveCorners.medium)
            .fill(CloveColors.card)
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Helper Methods
    
    private func loadInsights() {
        Task {
            await insightsEngine.generateInsights()
        }
    }
    
    private func refreshInsights() async {
        await insightsEngine.generateInsights()
    }
}

// MARK: - Insight Summary Badge

struct InsightSummaryBadge: View {
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: CloveSpacing.xsmall) {
            Text("\(count)")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(color)
            
            Text(label)
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText)
        }
    }
}

// MARK: - Insight Group View

struct InsightGroupView: View {
    let type: InsightType
    let insights: [HealthInsight]
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            HStack {
                Image(systemName: insights.first?.typeIcon ?? "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.shared.accent)
                
                Text(type.rawValue.capitalized)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Spacer()
                
                Text("\(insights.count)")
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
                    .padding(.horizontal, CloveSpacing.small)
                    .padding(.vertical, CloveSpacing.xsmall)
                    .background(
                        RoundedRectangle(cornerRadius: CloveCorners.full)
                            .fill(Theme.shared.accent.opacity(0.1))
                    )
            }
            
            VStack(spacing: CloveSpacing.small) {
                ForEach(insights) { insight in
                    InsightCardView(insight: insight)
                }
            }
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Insight Card View

struct InsightCardView: View {
    let insight: HealthInsight
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            HStack(alignment: .top, spacing: CloveSpacing.medium) {
                // Priority indicator
                priorityIndicator
                
                // Content
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    Text(insight.title)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(CloveColors.primaryText)
                        .lineLimit(isExpanded ? nil : 2)
                    
                    Text(insight.description)
                        .font(CloveFonts.body())
                        .foregroundStyle(CloveColors.secondaryText)
                        .lineLimit(isExpanded ? nil : 3)
                    
                    if isExpanded {
                        expandedContent
                    }
                }
                
                Spacer()
                
                // Expand button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(CloveColors.secondaryText)
                }
            }
            
            if isExpanded && insight.isActionable, let actionableText = insight.actionableText {
                actionableSection(actionableText)
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
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(priorityColor.opacity(0.3), lineWidth: 2)
                    .frame(width: 16, height: 16)
            )
    }
    
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            // Confidence indicator
            HStack(spacing: CloveSpacing.small) {
                Text("Confidence:")
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
                
                ProgressView(value: insight.confidence, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: Theme.shared.accent))
                    .frame(width: 60)
                
                Text("\(Int(insight.confidence * 100))%")
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
            }
            
            // Associated metrics
            if !insight.associatedMetrics.isEmpty {
                HStack(spacing: CloveSpacing.small) {
                    Text("Metrics:")
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                    
                    Text(insight.associatedMetrics.joined(separator: ", "))
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.primaryText)
                        .fontWeight(.medium)
                }
            }
            
            // Generated time
            Text("Generated \(insight.generatedAt.formatted(.relative(presentation: .named)))")
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText.opacity(0.7))
        }
    }
    
    private func actionableSection(_ actionableText: String) -> some View {
        HStack(spacing: CloveSpacing.medium) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 16))
                .foregroundStyle(Theme.shared.accent)
            
            Text(actionableText)
                .font(CloveFonts.body())
                .foregroundStyle(CloveColors.primaryText)
                .fontWeight(.medium)
        }
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(Theme.shared.accent.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke(Theme.shared.accent.opacity(0.2), lineWidth: 1)
                )
        )
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
        priorityColor.opacity(0.2)
    }
}

// MARK: - Insight Filter View

struct InsightFilterView: View {
    @Binding var selectedType: InsightType?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: CloveSpacing.large) {
                VStack(alignment: .leading, spacing: CloveSpacing.medium) {
                    Text("Filter Insights")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text("Choose a specific type of insight to view")
                        .font(CloveFonts.body())
                        .foregroundStyle(CloveColors.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: CloveSpacing.small) {
                    // All insights option
                    FilterOptionRow(
                        icon: "list.bullet",
                        title: "All Insights",
                        isSelected: selectedType == nil
                    ) {
                        selectedType = nil
                    }
                    
                    Divider()
                        .background(CloveColors.secondaryText.opacity(0.2))
                    
                    // Individual insight types
                    ForEach(InsightType.allCases, id: \.self) { type in
                        FilterOptionRow(
                            icon: iconForType(type),
                            title: type.rawValue.capitalized,
                            isSelected: selectedType == type
                        ) {
                            selectedType = type
                        }
                    }
                }
                
                Spacer()
            }
            .padding(CloveSpacing.large)
            .navigationTitle("Filter")
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
    
    private func iconForType(_ type: InsightType) -> String {
        switch type {
        case .trend: return "chart.line.uptrend.xyaxis"
        case .achievement: return "star.fill"
        case .pattern: return "sparkles"
        case .correlation: return "link"
        case .warning: return "exclamationmark.triangle.fill"
        case .recommendation: return "lightbulb.fill"
        }
    }
}

// MARK: - Filter Option Row

struct FilterOptionRow: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: CloveSpacing.medium) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Theme.shared.accent : CloveColors.secondaryText)
                    .frame(width: 24)
                
                Text(title)
                    .font(CloveFonts.body())
                    .foregroundStyle(isSelected ? Theme.shared.accent : CloveColors.primaryText)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.shared.accent)
                        .fontWeight(.semibold)
                }
            }
            .padding(CloveSpacing.medium)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .fill(isSelected ? Theme.shared.accent.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SmartInsightsView()
}
