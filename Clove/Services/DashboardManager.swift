import Foundation
import SwiftUI

enum WidgetType: String, CaseIterable, Identifiable, Codable {
    case trendOverview = "trend_overview", recentInsights = "recent_insights", streakCounter = "streak_counter"
    case weeklyPattern = "weekly_pattern", correlationHighlight = "correlation_highlight", healthScore = "health_score"
    var id: String { rawValue }
    var displayName: String { switch self { case .trendOverview: "Metrics Overview"; case .recentInsights: "Recent Insights"; case .streakCounter: "Streak Counter"; case .weeklyPattern: "Weekly Pattern"; case .correlationHighlight: "Saved Comparisons"; case .healthScore: "Wellbeing Snapshot" } }
    var icon: String { switch self { case .trendOverview: "chart.bar.fill"; case .recentInsights: "lightbulb.fill"; case .streakCounter: "flame.fill"; case .weeklyPattern: "calendar"; case .correlationHighlight: "link"; case .healthScore: "heart.text.square" } }
    var defaultSize: WidgetSize { self == .trendOverview ? .large : ([.recentInsights, .weeklyPattern].contains(self) ? .medium : .small) }
}

enum WidgetSize: String, CaseIterable, Codable {
    case small, medium, large
    var dimensions: (width: CGFloat, height: CGFloat) { switch self { case .small: (160, 160); case .medium: (160, 200); case .large: (340, 200) } }
}

struct DashboardWidget: Identifiable, Codable {
    var id = UUID(); let type: WidgetType; var size: WidgetSize; var position: Int; var isEnabled: Bool
    init(type: WidgetType, size: WidgetSize? = nil, position: Int = 0, isEnabled: Bool = true) { self.type = type; self.size = size ?? type.defaultSize; self.position = position; self.isEnabled = isEnabled }
}

struct MetricSummaryData {
    let definition: MetricDefinition; let currentValue: Double?; let previousValue: Double?; let trend: TrendDirection; let changePercentage: Double; let icon: String
    enum TrendDirection { case up, down, stable; var color: Color { self == .up ? .green : self == .down ? .red : .gray }; var icon: String { self == .up ? "arrow.up" : self == .down ? "arrow.down" : "minus" } }
    func formattedValue(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...definition.displayFormat.maximumFractionDigits)))
            + (definition.displayFormat.suffix ?? "")
    }
}

struct StreakData {
    let metricName: String; let currentStreak: Int; let longestStreak: Int; let isActive: Bool; let streakType: String
}

struct HealthScoreData {
    let overallScore: Double; let components: [ScoreComponent]; let trend: TrendDirection; let lastUpdated: Date
    struct ScoreComponent { let name: String; let score: Double; let weight: Double }
    enum TrendDirection { case improving, declining, stable; var color: Color { self == .improving ? .green : self == .declining ? .red : .gray } }
}

@MainActor
@Observable
final class DashboardManager {
    static let shared = DashboardManager()
    private let insightsEngine = InsightsEngine.shared
    var widgets: [DashboardWidget] = []
    var isLoading = false
    var lastRefreshTime: Date?
    var metricSummaries: [MetricSummaryData] = []
    var currentStreaks: [StreakData] = []
    var healthScore: HealthScoreData?
    var topInsights: [HealthInsight] = []
    var weeklyPatterns: [String: [Double]] = [:]
    var topCorrelation: (String, String, Double)?

    private init() { loadDefaultWidgets() }

    func loadDefaultWidgets() {
        widgets = [DashboardWidget(type: .healthScore, position: 0), DashboardWidget(type: .streakCounter, position: 1),
                   DashboardWidget(type: .recentInsights, position: 2), DashboardWidget(type: .trendOverview, position: 3),
                   DashboardWidget(type: .weeklyPattern, position: 4), DashboardWidget(type: .correlationHighlight, position: 5)]
        loadWidgetPreferences()
    }

    func refreshDashboard() async {
        isLoading = true; defer { isLoading = false }
        let factory = AnalyticsDateRangeFactory(); let interval = factory.interval(for: .month)
        let granularity = AnalyticsChartPipeline().granularity(for: interval)
        do {
            let current = try await AnalyticsRepositoryContainer.shared.load(AnalyticsRequest(interval: interval, includeRawEvents: true), granularity: granularity)
            let previous: AnalyticsDataset?
            if let previousInterval = factory.previous(equalTo: interval) {
                previous = try await AnalyticsRepositoryContainer.shared.load(
                    AnalyticsRequest(interval: previousInterval, includeRawEvents: true),
                    granularity: AnalyticsChartPipeline().granularity(for: previousInterval)
                )
            } else {
                previous = nil
            }
            await insightsEngine.generateInsights(forPeriod: .month)
            topInsights = Array(insightsEngine.currentInsights.prefix(4))
            loadSummaries(current: current, previous: previous)
            loadStreaks(current)
            loadSnapshot(current: current, previous: previous)
            loadWeekdays(current)
            topCorrelation = nil
            lastRefreshTime = Date()
        } catch {
            metricSummaries = []; currentStreaks = []; healthScore = nil; topInsights = []; weeklyPatterns = [:]; topCorrelation = nil
        }
    }

    func toggleWidget(_ type: WidgetType) { if let index = widgets.firstIndex(where: { $0.type == type }) { widgets[index].isEnabled.toggle(); saveWidgetPreferences() } }
    func updateWidgetSize(_ type: WidgetType, size: WidgetSize) { if let index = widgets.firstIndex(where: { $0.type == type }) { widgets[index].size = size; saveWidgetPreferences() } }
    func reorderWidgets(from source: IndexSet, to destination: Int) { widgets.move(fromOffsets: source, toOffset: destination); for index in widgets.indices { widgets[index].position = index }; saveWidgetPreferences() }

    private func loadSummaries(current: AnalyticsDataset, previous: AnalyticsDataset?) {
        metricSummaries = current.definitions.compactMap { definition -> MetricSummaryData? in
            let summary = MetricAnalysisSummaryEngine().summarize(definition: definition, dataset: current, previousDataset: previous)
            guard let value = summary.value?.comparisonScalar else { return nil }
            let previousValue = summary.comparison?.previous.comparisonScalar
            let change = previousValue.flatMap { $0 == 0 ? nil : (value - $0) / abs($0) * 100 } ?? 0
            let trend: MetricSummaryData.TrendDirection = abs(change) < 0.01 ? .stable : (change > 0 ? .up : .down)
            return MetricSummaryData(definition: definition, currentValue: value, previousValue: previousValue,
                trend: trend, changePercentage: change, icon: icon(for: definition.category))
        }.sorted { $0.definition.displayName < $1.definition.displayName }
    }

    private func icon(for category: MetricSemanticCategory) -> String {
        switch category {
        case .coreHealth: "💜"
        case .symptoms: "🩺"
        case .medications: "💊"
        case .lifestyle: "🌿"
        case .environmental: "🌤️"
        case .activities: "🏃"
        case .meals: "🍽️"
        }
    }

    private func loadStreaks(_ dataset: AnalyticsDataset) {
        let calendar = Calendar.current
        currentStreaks = dataset.definitions.compactMap { definition in
            let days = Set(dataset.observations(for: definition.id).compactMap { observation -> Date? in if case .observed = observation.state { calendar.startOfDay(for: observation.day) } else { nil } }).sorted()
            guard !days.isEmpty else { return nil }
            var longest = 1, current = 1
            for index in 1..<days.count { if calendar.dateComponents([.day], from: days[index - 1], to: days[index]).day == 1 { current += 1; longest = max(longest, current) } else { current = 1 } }
            let active = days.last == calendar.startOfDay(for: Date())
            return StreakData(metricName: definition.displayName, currentStreak: active ? current : 0, longestStreak: longest, isActive: active, streakType: "recorded days")
        }.filter { $0.longestStreak >= 2 }.sorted { $0.longestStreak > $1.longestStreak }
    }

    private func loadSnapshot(current: AnalyticsDataset, previous: AnalyticsDataset?) {
        let snapshot = WellbeingSnapshotEngine().build(current: current, previous: previous)
        let scored = snapshot.availableComponents.compactMap { component -> HealthScoreData.ScoreComponent? in
            guard let value = component.currentValue else { return nil }
            let score: Double = switch component.kind {
            case .mood, .energy: max(0, min(100, value / 10 * 100))
            case .pain, .symptoms: max(0, min(100, (10 - value) / 10 * 100))
            case .adherence: max(0, min(100, value))
            }
            return .init(name: component.kind.rawValue, score: score, weight: component.weight)
        }
        guard !scored.isEmpty else { healthScore = nil; return }
        let overall = scored.reduce(0) { $0 + $1.score * $1.weight }
        let favorable = snapshot.availableComponents.filter { $0.favorability == .favorable }.count
        let unfavorable = snapshot.availableComponents.filter { $0.favorability == .unfavorable }.count
        healthScore = HealthScoreData(overallScore: overall, components: scored,
            trend: favorable == unfavorable ? .stable : (favorable > unfavorable ? .improving : .declining), lastUpdated: Date())
    }

    private func loadWeekdays(_ dataset: AnalyticsDataset) {
        let calendar = Calendar.current
        weeklyPatterns = Dictionary(uniqueKeysWithValues: dataset.definitions.compactMap { definition -> (String, [Double])? in
            let values = dataset.observations(for: definition.id).compactMap { observation -> (Int, Double)? in
                guard case .observed(let value) = observation.state, let number = value.numericValue else { return nil }
                return (calendar.component(.weekday, from: observation.day), number)
            }
            guard !values.isEmpty else { return nil }
            let groups = Dictionary(grouping: values, by: \.0)
            return (definition.displayName, (1...7).map { day in let group = groups[day] ?? []; return group.isEmpty ? 0 : group.reduce(0) { $0 + $1.1 } / Double(group.count) })
        })
    }

    private func loadWidgetPreferences() { if let data = UserDefaults.standard.data(forKey: "dashboardWidgets"), let decoded = try? JSONDecoder().decode([DashboardWidget].self, from: data) { widgets = decoded.sorted { $0.position < $1.position } } }
    private func saveWidgetPreferences() { if let data = try? JSONEncoder().encode(widgets) { UserDefaults.standard.set(data, forKey: "dashboardWidgets") } }
}
