import SwiftUI

// MARK: - Metric Explorer View

struct MetricExplorer: View {
    @State private var viewModel = MetricExplorerViewModel()
    let onMetricSelected: (String) -> Void // Pass metric ID instead of SelectableMetric

    @Environment(\.dismiss) private var dismiss
    private let timePeriodManager = TimePeriodManager.shared
    @FocusState private var isSearchFocused: Bool

    @AppStorage(Constants.HIDE_INACTIVE_METRICS) var hideInactiveMetrics: Bool = false
    @State private var recentMetrics: [String] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and filter section
                searchAndFilterSection
                    .padding(.horizontal, CloveSpacing.large)
                    .padding(.top, CloveSpacing.large)
                
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else {
                    metricsContent
                }
            }
            .background(CloveColors.background.ignoresSafeArea())
            .navigationTitle("Metric Explorer")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.refresh()
                loadRecentMetrics()
            }
        }
    }
    
    // MARK: - Search and Filter Section
    
    private var searchAndFilterSection: some View {
        VStack(spacing: CloveSpacing.medium) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(isSearchFocused ? Theme.shared.accent : CloveColors.secondaryText)
                    .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
                
                TextField("Search metrics...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                        isSearchFocused = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(CloveColors.red)
                            .font(.system(size: 16, weight: .medium))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(CloveSpacing.small)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .fill(CloveColors.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: CloveCorners.medium)
                            .stroke(
                                isSearchFocused ? Theme.shared.accent.opacity(0.6) : Theme.shared.accent.opacity(0.2), 
                                lineWidth: isSearchFocused ? 2 : 1
                            )
                            .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
                    )
            )
            .padding(.bottom, 5)
            
            // Category filter chips
            categoryFilterChips
        }
    }
    
    private var categoryFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CloveSpacing.small) {
                // All categories chip
                MetricCategoryChip(
                    title: "All",
                    isSelected: viewModel.selectedCategory == nil,
                    onTap: {
                        viewModel.selectedCategory = nil
                    }
                )
                
                // Individual category chips
                ForEach(MetricCategory.allCases) { category in
                    MetricCategoryChip(
                        title: category.displayName,
                        isSelected: viewModel.selectedCategory == category,
                        onTap: {
                            viewModel.selectedCategory = category == viewModel.selectedCategory ? nil : category
                        }
                    )
                }
            }
            .padding(.bottom, 10)
        }
        .scrollClipDisabled()
    }
    
    // MARK: - Content Views
    
    private var loadingView: some View {
        VStack(spacing: CloveSpacing.large) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Theme.shared.accent)
            
            Text("Loading metrics...")
                .font(CloveFonts.body())
                .foregroundStyle(CloveColors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: CloveSpacing.large) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(CloveColors.red)
            
            Text("Error Loading Metrics")
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(CloveColors.primaryText)
            
            Text(error)
                .font(CloveFonts.body())
                .foregroundStyle(CloveColors.secondaryText)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                Task {
                    await viewModel.loadMetricSummaries()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.shared.accent)
        }
        .padding(CloveSpacing.xlarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var metricsContent: some View {
        ScrollView {
            VStack(spacing: CloveSpacing.large) {
                // Recent metrics section
                if !recentMetricsToDisplay.isEmpty {
                    recentMetricsSection
                }

                // Performance indicator
                performanceIndicator

                // Categorized metrics section
                categorizedMetricsSection

                // Empty state
                if viewModel.filteredMetrics().isEmpty {
                    emptyStateView
                }
            }
            .padding(.horizontal, CloveSpacing.large)
            .padding(.bottom, CloveSpacing.xlarge)
        }
    }
    
    private var performanceIndicator: some View {
        HStack {
            Image(systemName: "bolt.fill")
                .foregroundStyle(CloveColors.green)
                .font(.caption)
            
            Text("\(viewModel.metricSummaries.count) metrics available")
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText)
            
            Spacer()
            
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    hideInactiveMetrics.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    // The eye icon communicates "visibility"
                    Image(systemName: hideInactiveMetrics ? "eye" : "eye.slash.fill")
                        .contentTransition(.symbolEffect(.replace))

                    Text(hideInactiveMetrics ? "Show Inactive" : "Hide Inactive")
                        .contentTransition(.numericText())
                }
                .font(CloveFonts.small())
                // Use accent color when active to show a filter is applied
                .foregroundStyle(hideInactiveMetrics ? CloveColors.secondaryText : Theme.shared.accent)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    // subtle background when filter is applied
                    RoundedRectangle(cornerRadius: 8)
                        .fill(!hideInactiveMetrics ? Theme.shared.accent.opacity(0.1) : Color.clear)
                )
                .animation(.easeInOut(duration: 0.25), value: hideInactiveMetrics)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, CloveSpacing.medium)
    }
    
    private var categorizedMetricsSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.large) {
            let filteredMetrics = viewModel.filteredMetrics()
            let groupedMetrics = Dictionary(grouping: filteredMetrics) { $0.category }
            
            ForEach(MetricCategory.allCases) { category in
                if let metrics = groupedMetrics[category], !metrics.isEmpty {
                    CategorySectionV2(
                        category: category,
                        metrics: metrics,
                        onMetricSelected: { metricId in
                            saveRecentMetric(metricId)
                            onMetricSelected(metricId)
                            dismiss()
                        }
                    )
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: CloveSpacing.large) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundStyle(Theme.shared.accent.opacity(0.5))

            VStack(spacing: CloveSpacing.small) {
                Text("No metrics found for last \(TimePeriodManager.shared.currentPeriodDisplayText)")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(CloveColors.primaryText)

                if !viewModel.searchText.isEmpty {
                    Text("Try adjusting your search or filter")
                        .font(CloveFonts.body())
                        .foregroundStyle(CloveColors.secondaryText)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Start logging data to see available metrics, or try expanding time range.")
                        .font(CloveFonts.body())
                        .foregroundStyle(CloveColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CloveSpacing.xlarge)
    }

    // MARK: - Recent Metrics Section

    private var recentMetricsSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.shared.accent)
                Text("Recent")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(CloveColors.primaryText)

                Spacer()

                Button(action: clearRecentMetrics) {
                    Text("Clear")
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CloveSpacing.small) {
                    ForEach(recentMetricsToDisplay, id: \.id) { metric in
                        RecentMetricChip(metric: metric) {
                            saveRecentMetric(metric.id)
                            onMetricSelected(metric.id)
                            dismiss()
                        }
                    }
                }
            }
            .scrollClipDisabled()
        }
        .padding(.top, CloveSpacing.medium)
    }

    // MARK: - Helper Properties & Functions

    private var recentMetricsToDisplay: [MetricSummary] {
        // Get up to 4 most recent metrics that are available in current summaries
        recentMetrics.prefix(4).compactMap { metricId in
            viewModel.metricSummaries.first { $0.id == metricId }
        }
    }

    private func loadRecentMetrics() {
        if let data = UserDefaults.standard.array(forKey: Constants.RECENT_METRICS) as? [String] {
            recentMetrics = data
        }
    }

    private func saveRecentMetric(_ metricId: String) {
        // Remove if already exists to avoid duplicates
        recentMetrics.removeAll { $0 == metricId }
        // Add to front
        recentMetrics.insert(metricId, at: 0)
        // Keep only last 4
        if recentMetrics.count > 4 {
            recentMetrics = Array(recentMetrics.prefix(4))
        }
        // Save to UserDefaults
        UserDefaults.standard.set(recentMetrics, forKey: Constants.RECENT_METRICS)
    }

    private func clearRecentMetrics() {
        withAnimation {
            recentMetrics = []
        }
        UserDefaults.standard.removeObject(forKey: Constants.RECENT_METRICS)
    }
}

// MARK: - Supporting Views

struct MetricCategoryChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(CloveFonts.small())
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : CloveColors.secondaryText)
                .padding(.horizontal, CloveSpacing.medium)
                .padding(.vertical, CloveSpacing.small)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.full)
                        .fill(isSelected ? Theme.shared.accent : CloveColors.card)
                        .shadow(color: .gray.opacity(0.8), radius: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecentMetricChip: View {
    let metric: MetricSummary
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: CloveSpacing.small) {
                Text(metric.icon)
                    .font(.system(size: 16))

                Text(metric.displayName)
                    .font(CloveFonts.small())
                    .fontWeight(.medium)
                    .foregroundStyle(CloveColors.primaryText)
                    .lineLimit(1)
            }
            .padding(.horizontal, CloveSpacing.medium)
            .padding(.vertical, CloveSpacing.small)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .fill(CloveColors.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: CloveCorners.medium)
                            .stroke(Theme.shared.accent.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CategorySectionV2: View {
    let category: MetricCategory
    let metrics: [MetricSummary]
    let onMetricSelected: (String) -> Void
    
    @AppStorage(Constants.HIDE_INACTIVE_METRICS) var hideInactiveMetrics: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            Text(category.displayName)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(CloveColors.primaryText)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: CloveSpacing.medium) {
                ForEach(metrics, id: \.id) { metric in
                    if (metric.isActive ?? true) || !hideInactiveMetrics {
                        MetricCardV2(metric: metric) {
                            onMetricSelected(metric.id)
                        }
                    }
                }
            }
        }
    }
}

struct MetricCardV2: View {
    let metric: MetricSummary
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: CloveSpacing.medium) {
                HStack {
                    Text(metric.icon)
                        .font(.system(size: 20))
                    
                    Spacer()
                    
                    if metric.isActive ?? true {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(CloveColors.success)
                    } else {
                        Text("Inactive")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(5)
                            .background(
                                RoundedRectangle(cornerRadius: CloveCorners.medium)
                                    .fill(Color.red.opacity(0.5))
                            )
                    }
                }
                
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    Text(metric.displayName)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(CloveColors.primaryText)
                        .lineLimit(1)
                    
                    Text(metric.description)
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                        .lineLimit(2)
                }
                
                HStack {
                    if let lastValue = metric.lastValue {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Last")
                                .font(CloveFonts.small())
                                .foregroundStyle(CloveColors.secondaryText)
                            
                            Text(lastValue)
                                .font(CloveFonts.body())
                                .foregroundStyle(Theme.shared.accent)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Data Points")
                            .font(CloveFonts.small())
                            .foregroundStyle(CloveColors.secondaryText)
                        
                        Text("\(metric.dataPointCount)")
                            .font(CloveFonts.body())
                            .foregroundStyle(CloveColors.primaryText)
                            .fontWeight(.semibold)
                    }
                }
            }
            .padding(CloveSpacing.large)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .fill(CloveColors.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: CloveCorners.medium)
                            .stroke(
                                metric.isAvailable ? Theme.shared.accent.opacity(0.2) : CloveColors.secondaryText.opacity(0.1),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(metric.isAvailable ? 1.0 : 0.6)
    }
}

// MARK: - Preview

#Preview {
    MetricCardV2(metric: MetricSummary(id: "mockMetricId", displayName: "Mock Metric", description: "This is a fake metric.", icon: "🎄", category: .symptoms, dataPointCount: 70, lastValue: "5", isAvailable: true, isActive: false)) {}
        .frame(maxWidth: 200)
}

#Preview {
    MetricExplorer { metricId in
        print("Selected metric: \(metricId)")
    }
}
