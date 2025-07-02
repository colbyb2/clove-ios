import Foundation
import SwiftUI

// MARK: - Dashboard Models

enum WidgetType: String, CaseIterable, Identifiable, Codable {
    case trendOverview = "trend_overview"
    case recentInsights = "recent_insights"
    case streakCounter = "streak_counter"
    case weeklyPattern = "weekly_pattern"
    case correlationHighlight = "correlation_highlight"
    case healthScore = "health_score"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .trendOverview: return "Metrics Overview"
        case .recentInsights: return "Recent Insights"
        case .streakCounter: return "Streak Counter"
        case .weeklyPattern: return "Weekly Pattern"
        case .correlationHighlight: return "Top Correlation"
        case .healthScore: return "Health Score"
        }
    }
    
    var icon: String {
        switch self {
        case .trendOverview: return "chart.bar.fill"
        case .recentInsights: return "lightbulb.fill"
        case .streakCounter: return "flame.fill"
        case .weeklyPattern: return "calendar"
        case .correlationHighlight: return "link"
        case .healthScore: return "heart.fill"
        }
    }
    
    var defaultSize: WidgetSize {
        switch self {
        case .trendOverview: return .large
        case .recentInsights, .weeklyPattern: return .medium
        case .streakCounter, .healthScore, .correlationHighlight: return .small
        }
    }
}

enum WidgetSize: String, CaseIterable, Codable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    
    var dimensions: (width: CGFloat, height: CGFloat) {
        switch self {
        case .small: return (160, 160)
        case .medium: return (160, 200)
        case .large: return (340, 200)
        }
    }
}

struct DashboardWidget: Identifiable, Codable {
    var id = UUID()
    let type: WidgetType
    var size: WidgetSize
    var position: Int
    var isEnabled: Bool
    
    init(type: WidgetType, size: WidgetSize? = nil, position: Int = 0, isEnabled: Bool = true) {
        self.type = type
        self.size = size ?? type.defaultSize
        self.position = position
        self.isEnabled = isEnabled
    }
}

struct MetricSummaryData {
    let metric: MetricType
    let currentValue: Double?
    let previousValue: Double?
    let trend: TrendDirection
    let changePercentage: Double
    let icon: String
    
    enum TrendDirection {
        case up, down, stable
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .stable: return .gray
            }
        }
        
        var icon: String {
            switch self {
            case .up: return "arrow.up"
            case .down: return "arrow.down"
            case .stable: return "minus"
            }
        }
    }
}

struct StreakData {
    let metricName: String
    let currentStreak: Int
    let longestStreak: Int
    let isActive: Bool
    let streakType: String // "good days", "pain-free days", etc.
}

struct HealthScoreData {
    let overallScore: Double // 0-100
    let components: [ScoreComponent]
    let trend: TrendDirection
    let lastUpdated: Date
    
    struct ScoreComponent {
        let name: String
        let score: Double
        let weight: Double
    }
    
    enum TrendDirection {
        case improving, declining, stable
        
        var color: Color {
            switch self {
            case .improving: return .green
            case .declining: return .red
            case .stable: return .gray
            }
        }
    }
}

// MARK: - Dashboard Manager

@Observable
class DashboardManager {
    static let shared = DashboardManager()
    
    private let chartDataManager = ChartDataManager.shared
    private let insightsEngine = InsightsEngine.shared
    private let timePeriodManager = TimePeriodManager.shared
    
    var widgets: [DashboardWidget] = []
    var isLoading: Bool = false
    var lastRefreshTime: Date?
    
    // Cached data
    var metricSummaries: [MetricSummaryData] = []
    var currentStreaks: [StreakData] = []
    var healthScore: HealthScoreData?
    var topInsights: [HealthInsight] = []
    var weeklyPatterns: [String: [Double]] = [:]
    var topCorrelation: (String, String, Double)?
    
    private init() {
        loadDefaultWidgets()
    }
    
    // MARK: - Widget Management
    
    func loadDefaultWidgets() {
        widgets = [
            DashboardWidget(type: .healthScore, position: 0),
            DashboardWidget(type: .streakCounter, position: 1),
            DashboardWidget(type: .recentInsights, position: 2),
            DashboardWidget(type: .trendOverview, position: 3),
            DashboardWidget(type: .weeklyPattern, position: 4),
            DashboardWidget(type: .correlationHighlight, position: 5)
        ]
        
        loadWidgetPreferences()
    }
    
    func refreshDashboard() async {
        await MainActor.run {
            self.isLoading = true
        }
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadMetricSummaries() }
            group.addTask { await self.loadStreakData() }
            group.addTask { await self.loadHealthScore() }
            group.addTask { await self.loadTopInsights() }
            group.addTask { await self.loadWeeklyPatterns() }
            group.addTask { await self.loadTopCorrelation() }
        }
        
        await MainActor.run {
            self.lastRefreshTime = Date()
            self.isLoading = false
        }
    }
    
    func toggleWidget(_ widgetType: WidgetType) {
        if let index = widgets.firstIndex(where: { $0.type == widgetType }) {
            widgets[index].isEnabled.toggle()
            saveWidgetPreferences()
        }
    }
    
    func updateWidgetSize(_ widgetType: WidgetType, size: WidgetSize) {
        if let index = widgets.firstIndex(where: { $0.type == widgetType }) {
            widgets[index].size = size
            saveWidgetPreferences()
        }
    }
    
    func reorderWidgets(from source: IndexSet, to destination: Int) {
        widgets.move(fromOffsets: source, toOffset: destination)
        for (index, widget) in widgets.enumerated() {
            widgets[index].position = index
        }
        saveWidgetPreferences()
    }
    
    // MARK: - Data Loading
    
    private func loadMetricSummaries() async {
        let availableMetrics = chartDataManager.getAvailableMetrics()
        var summaries: [MetricSummaryData] = []
        
        for metric in availableMetrics.prefix(4) { // Limit to top 4 metrics
            let currentData = chartDataManager.getChartData(for: metric, period: .week)
            let previousData = chartDataManager.getChartData(for: metric, period: .month)
            
            guard !currentData.isEmpty else { continue }
            
            let currentValue = currentData.last?.value
            let currentWeekAvg = currentData.map { $0.value }.reduce(0, +) / Double(currentData.count)
            
            // Calculate previous week average for comparison
            let allMonthData = previousData.sorted { $0.date < $1.date }
            let previousWeekData = allMonthData.dropLast(currentData.count).suffix(7)
            let previousWeekAvg = previousWeekData.isEmpty ? currentWeekAvg : 
                previousWeekData.map { $0.value }.reduce(0, +) / Double(previousWeekData.count)
            
            let changePercentage = previousWeekAvg != 0 ? 
                ((currentWeekAvg - previousWeekAvg) / previousWeekAvg) * 100 : 0
            
            let trend: MetricSummaryData.TrendDirection
            if abs(changePercentage) < 5 {
                trend = .stable
            } else if changePercentage > 0 {
                trend = metric == .painLevel ? .down : .up // Lower pain is better
            } else {
                trend = metric == .painLevel ? .up : .down
            }
            
            summaries.append(MetricSummaryData(
                metric: metric,
                currentValue: currentValue,
                previousValue: previousWeekAvg,
                trend: trend,
                changePercentage: abs(changePercentage),
                icon: metric.icon
            ))
        }
        
        await MainActor.run {
            self.metricSummaries = summaries
        }
    }
    
    private func loadStreakData() async {
        var streaks: [StreakData] = []
        let availableMetrics = chartDataManager.getAvailableMetrics()
        
        for metric in availableMetrics.prefix(3) {
            let data = chartDataManager.getChartData(for: metric, period: .month)
                .sorted { $0.date < $1.date }
            
            guard data.count >= 3 else { continue }
            
            let threshold = getGoodThreshold(for: metric)
            let recentValues = data.suffix(30).map { $0.value }
            
            let currentStreak = calculateCurrentStreak(values: recentValues, threshold: threshold, metric: metric)
            let longestStreak = calculateLongestStreak(values: recentValues, threshold: threshold, metric: metric)
            
            if currentStreak > 0 || longestStreak >= 3 {
                streaks.append(StreakData(
                    metricName: metric.displayName,
                    currentStreak: currentStreak,
                    longestStreak: longestStreak,
                    isActive: currentStreak > 0,
                    streakType: getStreakType(for: metric)
                ))
            }
        }
        
        await MainActor.run {
            self.currentStreaks = streaks.sorted { $0.currentStreak > $1.currentStreak }
        }
    }
    
    private func loadHealthScore() async {
        let availableMetrics = chartDataManager.getAvailableMetrics()
        guard !availableMetrics.isEmpty else { return }
        
        var components: [HealthScoreData.ScoreComponent] = []
        var totalWeightedScore = 0.0
        var totalWeight = 0.0
        
        for metric in availableMetrics {
            let data = chartDataManager.getChartData(for: metric, period: .week)
            guard !data.isEmpty else { continue }
            
            let average = data.map { $0.value }.reduce(0, +) / Double(data.count)
            let normalizedScore = normalizeMetricScore(metric: metric, value: average)
            let weight = getMetricWeight(metric)
            
            components.append(HealthScoreData.ScoreComponent(
                name: metric.displayName,
                score: normalizedScore,
                weight: weight
            ))
            
            totalWeightedScore += normalizedScore * weight
            totalWeight += weight
        }
        
        let overallScore = totalWeight > 0 ? totalWeightedScore / totalWeight : 0
        
        // Calculate trend by comparing with previous week
        let previousScore = await calculatePreviousHealthScore()
        let trend: HealthScoreData.TrendDirection
        let scoreDiff = overallScore - previousScore
        
        if abs(scoreDiff) < 2 {
            trend = .stable
        } else if scoreDiff > 0 {
            trend = .improving
        } else {
            trend = .declining
        }
        
        await MainActor.run {
            self.healthScore = HealthScoreData(
                overallScore: overallScore,
                components: components,
                trend: trend,
                lastUpdated: Date()
            )
        }
    }
    
    private func loadTopInsights() async {
        await insightsEngine.generateInsights(forPeriod: .week)
        
        await MainActor.run {
            self.topInsights = Array(insightsEngine.currentInsights.prefix(3))
        }
    }
    
    private func loadWeeklyPatterns() async {
        let availableMetrics = chartDataManager.getAvailableMetrics()
        var patterns: [String: [Double]] = [:]
        
        for metric in availableMetrics.prefix(2) {
            let data = chartDataManager.getChartData(for: metric, period: .month)
            let weeklyPattern = calculateWeeklyPattern(data: data)
            if !weeklyPattern.isEmpty {
                patterns[metric.displayName] = weeklyPattern
            }
        }
        
        await MainActor.run {
            self.weeklyPatterns = patterns
        }
    }
    
    private func loadTopCorrelation() async {
        let availableMetrics = chartDataManager.getAvailableMetrics()
        guard availableMetrics.count >= 2 else { return }
        
        var bestCorrelation: (String, String, Double) = ("", "", 0)
        
        for i in 0..<availableMetrics.count {
            for j in (i+1)..<availableMetrics.count {
                let metric1 = availableMetrics[i]
                let metric2 = availableMetrics[j]
                
                let correlation = calculateCorrelation(metric1: metric1, metric2: metric2)
                if abs(correlation) > abs(bestCorrelation.2) {
                    bestCorrelation = (metric1.displayName, metric2.displayName, correlation)
                }
            }
        }
        
        if abs(bestCorrelation.2) > 0.3 {
            await MainActor.run {
                self.topCorrelation = bestCorrelation
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getGoodThreshold(for metric: MetricType) -> Double {
        switch metric {
        case .mood, .energyLevel: return 6.0
        case .painLevel: return 4.0
        case .medicationAdherence: return 80.0
        default: return 5.0
        }
    }
    
    private func getStreakType(for metric: MetricType) -> String {
        switch metric {
        case .mood: return "good mood days"
        case .painLevel: return "low pain days"
        case .energyLevel: return "high energy days"
        case .medicationAdherence: return "adherent days"
        default: return "good days"
        }
    }
    
    private func calculateCurrentStreak(values: [Double], threshold: Double, metric: MetricType) -> Int {
        var streak = 0
        for value in values.reversed() {
            let isGood = metric == .painLevel ? value <= threshold : value >= threshold
            if isGood {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }
    
    private func calculateLongestStreak(values: [Double], threshold: Double, metric: MetricType) -> Int {
        var longestStreak = 0
        var currentStreak = 0
        
        for value in values {
            let isGood = metric == .painLevel ? value <= threshold : value >= threshold
            if isGood {
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else {
                currentStreak = 0
            }
        }
        
        return longestStreak
    }
    
    private func normalizeMetricScore(metric: MetricType, value: Double) -> Double {
        switch metric {
        case .mood, .energyLevel:
            return min(100, max(0, (value / 10.0) * 100))
        case .painLevel:
            return min(100, max(0, ((10.0 - value) / 10.0) * 100))
        case .medicationAdherence:
            return min(100, max(0, value))
        default:
            return min(100, max(0, (value / 10.0) * 100))
        }
    }
    
    private func getMetricWeight(_ metric: MetricType) -> Double {
        switch metric {
        case .mood: return 1.0
        case .painLevel: return 1.0
        case .energyLevel: return 0.8
        case .medicationAdherence: return 0.9
        default: return 0.5
        }
    }
    
    private func calculatePreviousHealthScore() async -> Double {
        // Simplified calculation for previous week's health score
        return healthScore?.overallScore ?? 0
    }
    
    private func calculateWeeklyPattern(data: [ChartDataPoint]) -> [Double] {
        let calendar = Calendar.current
        var weekdayTotals: [Int: (sum: Double, count: Int)] = [:]
        
        for point in data {
            let weekday = calendar.component(.weekday, from: point.date)
            let current = weekdayTotals[weekday] ?? (0, 0)
            weekdayTotals[weekday] = (current.sum + point.value, current.count + 1)
        }
        
        var pattern: [Double] = []
        for weekday in 1...7 {
            if let total = weekdayTotals[weekday], total.count > 0 {
                pattern.append(total.sum / Double(total.count))
            } else {
                pattern.append(0)
            }
        }
        
        return pattern
    }
    
    private func calculateCorrelation(metric1: MetricType, metric2: MetricType) -> Double {
        let data1 = chartDataManager.getChartData(for: metric1, period: .month)
        let data2 = chartDataManager.getChartData(for: metric2, period: .month)
        
        let calendar = Calendar.current
        var pairs: [(Double, Double)] = []
        
        for point1 in data1 {
            if let point2 = data2.first(where: { calendar.isDate($0.date, inSameDayAs: point1.date) }) {
                pairs.append((point1.value, point2.value))
            }
        }
        
        guard pairs.count >= 3 else { return 0 }
        
        let n = Double(pairs.count)
        let sumX = pairs.map { $0.0 }.reduce(0, +)
        let sumY = pairs.map { $0.1 }.reduce(0, +)
        let sumXY = pairs.map { $0.0 * $0.1 }.reduce(0, +)
        let sumXX = pairs.map { $0.0 * $0.0 }.reduce(0, +)
        let sumYY = pairs.map { $0.1 * $0.1 }.reduce(0, +)
        
        let numerator = n * sumXY - sumX * sumY
        let denominator = sqrt((n * sumXX - sumX * sumX) * (n * sumYY - sumY * sumY))
        
        return denominator != 0 ? numerator / denominator : 0
    }
    
    // MARK: - Persistence
    
    private func loadWidgetPreferences() {
        if let data = UserDefaults.standard.data(forKey: "dashboardWidgets"),
           let decodedWidgets = try? JSONDecoder().decode([DashboardWidget].self, from: data) {
            widgets = decodedWidgets.sorted { $0.position < $1.position }
        }
    }
    
    private func saveWidgetPreferences() {
        if let encoded = try? JSONEncoder().encode(widgets) {
            UserDefaults.standard.set(encoded, forKey: "dashboardWidgets")
        }
    }
}
