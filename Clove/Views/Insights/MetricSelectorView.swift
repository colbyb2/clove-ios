import SwiftUI

// MARK: - Data Models

struct SelectableMetric: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let type: MetricType?
    let symptomName: String?
    let category: MetricCategory
    let icon: String
    let description: String
    let isAvailable: Bool
    let lastValue: String?
    let dataPointCount: Int
    
    init(
        name: String,
        type: MetricType? = nil,
        symptomName: String? = nil,
        category: MetricCategory,
        icon: String,
        description: String,
        isAvailable: Bool,
        lastValue: String? = nil,
        dataPointCount: Int
    ) {
        self.name = name
        self.type = type
        self.symptomName = symptomName
        self.category = category
        self.icon = icon
        self.description = description
        self.isAvailable = isAvailable
        self.lastValue = lastValue
        self.dataPointCount = dataPointCount
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SelectableMetric, rhs: SelectableMetric) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Metric Selector ViewModel

@Observable
class MetricSelectorViewModel {
    var searchText: String = ""
    var selectedCategory: MetricCategory? = nil
    var recentMetrics: [SelectableMetric] = []
    var availableMetrics: [SelectableMetric] = []
    
    private let chartDataManager = ChartDataManager.shared
    private let symptomsRepo = SymptomsRepo.shared
    private let logsRepo = LogsRepo.shared
    
    init() {
        loadRecentMetrics()
        loadAvailableMetrics()
    }
    
    func loadMetrics() {
        loadRecentMetrics()
        loadAvailableMetrics()
    }
    
    func filterMetrics() -> [SelectableMetric] {
        var filtered = availableMetrics
        
        // Filter by category if selected
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { metric in
                metric.name.localizedCaseInsensitiveContains(searchText) ||
                metric.description.localizedCaseInsensitiveContains(searchText) ||
                metric.category.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort by availability first, then by name
        return filtered.sorted { metric1, metric2 in
            if metric1.isAvailable != metric2.isAvailable {
                return metric1.isAvailable && !metric2.isAvailable
            }
            return metric1.name < metric2.name
        }
    }
    
    func addToRecent(metric: SelectableMetric) {
        // Remove if already exists
        recentMetrics.removeAll { $0.id == metric.id }
        
        // Add to front
        recentMetrics.insert(metric, at: 0)
        
        // Keep only last 5
        if recentMetrics.count > 5 {
            recentMetrics = Array(recentMetrics.prefix(5))
        }
        
        // Save to UserDefaults
        saveRecentMetrics()
    }
    
    private func loadRecentMetrics() {
        // Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "recentMetrics"),
           let decoded = try? JSONDecoder().decode([RecentMetricData].self, from: data) {
            
            // Convert back to SelectableMetric (we'll need to reload the current data)
            recentMetrics = decoded.compactMap { recentData in
                createSelectableMetric(from: recentData)
            }
        }
    }
    
    private func saveRecentMetrics() {
        // Convert to serializable format
        let recentData = recentMetrics.map { metric in
            RecentMetricData(
                name: metric.name,
                type: metric.type?.rawValue,
                symptomName: metric.symptomName,
                category: metric.category.rawValue
            )
        }
        
        if let encoded = try? JSONEncoder().encode(recentData) {
            UserDefaults.standard.set(encoded, forKey: "recentMetrics")
        }
    }
    
    private func createSelectableMetric(from recentData: RecentMetricData) -> SelectableMetric? {
        if let typeRaw = recentData.type, let type = MetricType(rawValue: typeRaw) {
            // Core health metric
            return createCoreHealthMetric(type: type)
        } else if let symptomName = recentData.symptomName {
            // Symptom metric
            return createSymptomMetric(symptomName: symptomName)
        }
        return nil
    }
    
    private func loadAvailableMetrics() {
        var metrics: [SelectableMetric] = []
        
        // Load core health metrics
        let availableCoreMetrics = chartDataManager.getAvailableMetrics()
        for metricType in availableCoreMetrics {
            if let metric = createCoreHealthMetric(type: metricType) {
                metrics.append(metric)
            }
        }
        
        // Load symptom metrics
        let availableSymptoms = chartDataManager.getAvailableSymptoms()
        for symptomName in availableSymptoms {
            if let metric = createSymptomMetric(symptomName: symptomName) {
                metrics.append(metric)
            }
        }
        
        availableMetrics = metrics
    }
    
    private func createCoreHealthMetric(type: MetricType) -> SelectableMetric? {
        let dataPointCount = chartDataManager.getDataPointCount(for: type)
        let isAvailable = dataPointCount > 0
        
        // Get last value
        let recentData = chartDataManager.getChartData(for: type, period: .week)
        let lastValue = recentData.last?.value
        
        let formattedLastValue: String? = {
            guard let value = lastValue else { return nil }
            
            switch type {
            case .mood, .painLevel, .energyLevel:
                return String(Int(value.rounded()))
            case .medicationAdherence:
                return String(format: "%.0f%%", value)
            case .flareDay:
                return value == 1.0 ? "Yes" : "No"
            case .activityCount, .mealCount:
                return String(Int(value))
            case .weather:
                return convertNumericToWeather(value)
            }
        }()
        
        return SelectableMetric(
            name: type.displayName,
            type: type,
            category: type.category,
            icon: type.icon,
            description: type.description,
            isAvailable: isAvailable,
            lastValue: formattedLastValue,
            dataPointCount: dataPointCount
        )
    }
    
    private func createSymptomMetric(symptomName: String) -> SelectableMetric? {
        let dataPointCount = chartDataManager.getSymptomDataPointCount(symptomName: symptomName)
        let isAvailable = dataPointCount > 0
        
        // Get last value
        let recentData = chartDataManager.getSymptomChartData(symptomName: symptomName, period: .week)
        let lastValue = recentData.last?.value
        
        let formattedLastValue: String? = {
            guard let value = lastValue else { return nil }
            return String(Int(value.rounded()))
        }()
        
        return SelectableMetric(
            name: symptomName,
            symptomName: symptomName,
            category: .symptoms,
            icon: "🩹",
            description: "1-10 scale tracking \(symptomName.lowercased()) severity",
            isAvailable: isAvailable,
            lastValue: formattedLastValue,
            dataPointCount: dataPointCount
        )
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

// MARK: - Supporting Data Structure

private struct RecentMetricData: Codable {
    let name: String
    let type: String?
    let symptomName: String?
    let category: String
}

// MARK: - Metric Selector View

struct MetricSelectorView: View {
    @State private var viewModel = MetricSelectorViewModel()
    let selectedMetric: SelectableMetric?
    let onMetricSelected: (SelectableMetric) -> Void
    
    init(selectedMetric: SelectableMetric? = nil, onMetricSelected: @escaping (SelectableMetric) -> Void) {
        self.selectedMetric = selectedMetric
        self.onMetricSelected = onMetricSelected
    }
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and filter section
                searchAndFilterSection
                    .padding(.horizontal, CloveSpacing.large)
                    .padding(.top, CloveSpacing.large)
                
                ScrollView {
                    VStack(spacing: CloveSpacing.large) {
                        // Recent metrics section
                        if !viewModel.recentMetrics.isEmpty {
                            recentMetricsSection
                                .padding(.top, CloveSpacing.medium)
                        }
                        
                        // Categorized metrics section
                        categorizedMetricsSection
                        
                        // Empty state
                        if viewModel.filterMetrics().isEmpty {
                            emptyStateView
                        }
                    }
                    .padding(.horizontal, CloveSpacing.large)
                    .padding(.bottom, CloveSpacing.xlarge)
                }
            }
            .background(CloveColors.background.ignoresSafeArea())
            .navigationTitle("Select Metric")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(CloveColors.secondaryText)
                }
            }
        }
        .onAppear {
            viewModel.loadMetrics()
        }
    }
    
    // MARK: - Search and Filter Section
    
    private var searchAndFilterSection: some View {
        VStack(spacing: CloveSpacing.medium) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(CloveColors.secondaryText)
                
                TextField("Search metrics...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(CloveColors.secondaryText)
                    }
                }
            }
            .padding(CloveSpacing.medium)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .fill(CloveColors.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: CloveCorners.medium)
                            .stroke(CloveColors.accent.opacity(0.2), lineWidth: 1)
                    )
            )
            
            // Category filter chips
            categoryFilterChips
        }
    }
    
    private var categoryFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CloveSpacing.small) {
                // All categories chip
                InsightsCategoryChip(
                    title: "All",
                    isSelected: viewModel.selectedCategory == nil,
                    onTap: {
                        viewModel.selectedCategory = nil
                    }
                )
                
                // Individual category chips
                ForEach(MetricCategory.allCases) { category in
                    InsightsCategoryChip(
                        title: category.displayName,
                        isSelected: viewModel.selectedCategory == category,
                        onTap: {
                            viewModel.selectedCategory = category == viewModel.selectedCategory ? nil : category
                        }
                    )
                }
            }
            .padding(.horizontal, CloveSpacing.large)
        }
        .scrollClipDisabled()
    }
    
    // MARK: - Recent Metrics Section
    
    private var recentMetricsSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            HStack {
                Text("Recently Viewed")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Spacer()
                
                Text("\(viewModel.recentMetrics.count)")
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
                    .padding(.horizontal, CloveSpacing.small)
                    .padding(.vertical, CloveSpacing.xsmall)
                    .background(
                        RoundedRectangle(cornerRadius: CloveCorners.small)
                            .fill(CloveColors.accent.opacity(0.1))
                    )
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CloveSpacing.medium) {
                    ForEach(viewModel.recentMetrics) { metric in
                        CompactInsightsMetricCard(metric: metric) {
                            selectMetric(metric)
                        }
                    }
                }
                .padding(.horizontal, CloveSpacing.large)
            }
            .scrollClipDisabled()
        }
    }
    
    // MARK: - Categorized Metrics Section
    
    private var categorizedMetricsSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.large) {
            let filteredMetrics = viewModel.filterMetrics()
            let groupedMetrics = Dictionary(grouping: filteredMetrics) { $0.category }
            
            ForEach(MetricCategory.allCases) { category in
                if let metrics = groupedMetrics[category], !metrics.isEmpty {
                    CategorySection(category: category, metrics: metrics) { metric in
                        selectMetric(metric)
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: CloveSpacing.large) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundStyle(CloveColors.accent.opacity(0.5))
            
            VStack(spacing: CloveSpacing.small) {
                Text("No metrics found")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(CloveColors.primaryText)
                
                if !viewModel.searchText.isEmpty {
                    Text("Try adjusting your search or filter")
                        .font(CloveFonts.body())
                        .foregroundStyle(CloveColors.secondaryText)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Start logging data to see available metrics")
                        .font(CloveFonts.body())
                        .foregroundStyle(CloveColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CloveSpacing.xlarge)
    }
    
    // MARK: - Helper Methods
    
    private func selectMetric(_ metric: SelectableMetric) {
        viewModel.addToRecent(metric: metric)
        onMetricSelected(metric)
        dismiss()
    }
}

// MARK: - Supporting Views

struct InsightsCategoryChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(CloveFonts.small())
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : CloveColors.accent)
                .padding(.horizontal, CloveSpacing.medium)
                .padding(.vertical, CloveSpacing.small)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.full)
                        .fill(isSelected ? CloveColors.accent : CloveColors.accent.opacity(0.1))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CompactInsightsMetricCard: View {
    let metric: SelectableMetric
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: CloveSpacing.small) {
                Text(metric.icon)
                    .font(.system(size: 24))
                
                Text(metric.name)
                    .font(CloveFonts.small())
                    .fontWeight(.medium)
                    .foregroundStyle(CloveColors.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                if let lastValue = metric.lastValue {
                    Text(lastValue)
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.accent)
                        .fontWeight(.semibold)
                }
            }
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .fill(CloveColors.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: CloveCorners.medium)
                            .stroke(CloveColors.accent.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(metric.isAvailable ? 1.0 : 0.6)
    }
}

struct CategorySection: View {
    let category: MetricCategory
    let metrics: [SelectableMetric]
    let onMetricSelected: (SelectableMetric) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            Text(category.displayName)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(CloveColors.primaryText)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: CloveSpacing.medium) {
                ForEach(metrics) { metric in
                    InsightsMetricCard(metric: metric) {
                        onMetricSelected(metric)
                    }
                }
            }
        }
    }
}

struct InsightsMetricCard: View {
    let metric: SelectableMetric
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: CloveSpacing.medium) {
                HStack {
                    Text(metric.icon)
                        .font(.system(size: 20))
                    
                    Spacer()
                    
                    if metric.isAvailable {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(CloveColors.success)
                    } else {
                        Image(systemName: "circle")
                            .font(.system(size: 16))
                            .foregroundStyle(CloveColors.secondaryText.opacity(0.5))
                    }
                }
                
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    Text(metric.name)
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
                                .foregroundStyle(CloveColors.accent)
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
                                metric.isAvailable ? CloveColors.accent.opacity(0.2) : CloveColors.secondaryText.opacity(0.1),
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
    MetricSelectorView { metric in
        print("Selected: \(metric.name)")
    }
}
