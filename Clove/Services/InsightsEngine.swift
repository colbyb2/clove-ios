import Foundation

// MARK: - Insight Models

enum InsightType: String, CaseIterable {
    case trend = "trend"
    case achievement = "achievement"
    case pattern = "pattern"
    case correlation = "correlation"
    case warning = "warning"
    case recommendation = "recommendation"
}

enum InsightPriority: Int, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
}

struct HealthInsight: Identifiable, Hashable {
    let id = UUID()
    let type: InsightType
    let priority: InsightPriority
    let title: String
    let description: String
    let actionableText: String?
    let confidence: Double // 0.0 to 1.0
    let relevancePeriod: DateInterval
    let associatedMetrics: [String]
    let generatedAt: Date
    let isActionable: Bool
    
    var priorityColor: String {
        switch priority {
        case .low: return "blue"
        case .medium: return "orange"
        case .high: return "red"
        case .critical: return "purple"
        }
    }
    
    var typeIcon: String {
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

struct TrendAnalysis {
    let metric: String
    let direction: TrendDirection
    let magnitude: Double
    let timeframe: String
    let confidence: Double
    let isSignificant: Bool
    
    enum TrendDirection {
        case improving, declining, stable
        
        var displayText: String {
            switch self {
            case .improving: return "improving"
            case .declining: return "declining"
            case .stable: return "stable"
            }
        }
    }
}

struct PatternAnalysis {
    let metric: String
    let patternType: PatternType
    let frequency: String
    let strength: Double
    let description: String
    
    enum PatternType {
        case weekly, monthly, seasonal, cyclical
        
        var displayText: String {
            switch self {
            case .weekly: return "weekly"
            case .monthly: return "monthly"
            case .seasonal: return "seasonal"
            case .cyclical: return "cyclical"
            }
        }
    }
}

// MARK: - Insights Engine

@Observable
class InsightsEngine {
    static let shared = InsightsEngine()
    
    private let chartDataManager = ChartDataManager.shared
    private let timePeriodManager = TimePeriodManager.shared
    
    var currentInsights: [HealthInsight] = []
    var isGeneratingInsights: Bool = false
    var lastGenerationTime: Date?
    
    private init() {}
    
    // MARK: - Public API
    
    func generateInsights(forPeriod period: TimePeriod = .month) async {
        isGeneratingInsights = true
        
        do {
            let insights = try await performInsightGeneration(period: period)
            await MainActor.run {
                self.currentInsights = insights.sorted { $0.priority.rawValue > $1.priority.rawValue }
                self.lastGenerationTime = Date()
                self.isGeneratingInsights = false
            }
        } catch {
            await MainActor.run {
                self.isGeneratingInsights = false
            }
        }
    }
    
    func getInsights(ofType type: InsightType) -> [HealthInsight] {
        return currentInsights.filter { $0.type == type }
    }
    
    func getHighPriorityInsights() -> [HealthInsight] {
        return currentInsights.filter { $0.priority == .high || $0.priority == .critical }
    }
    
    func getActionableInsights() -> [HealthInsight] {
        return currentInsights.filter { $0.isActionable }
    }
    
    // MARK: - Insight Generation
    
    private func performInsightGeneration(period: TimePeriod) async throws -> [HealthInsight] {
        var insights: [HealthInsight] = []
        
        // Generate trend insights
        insights += await generateTrendInsights(period: period)
        
        // Generate achievement insights
        insights += await generateAchievementInsights(period: period)
        
        // Generate pattern insights
        insights += await generatePatternInsights(period: period)
        
        // Generate correlation insights
        insights += await generateCorrelationInsights(period: period)
        
        // Generate warning insights
        insights += await generateWarningInsights(period: period)
        
        // Generate recommendation insights
        insights += await generateRecommendationInsights(period: period)
        
        return insights
    }
    
    // MARK: - Trend Insights
    
    private func generateTrendInsights(period: TimePeriod) async -> [HealthInsight] {
        var insights: [HealthInsight] = []
        let availableMetrics = chartDataManager.getAvailableMetrics()
        
        for metric in availableMetrics {
            let data = chartDataManager.getChartData(for: metric, period: period)
            guard !data.isEmpty else { continue }
            
            let trendAnalysis = analyzeTrend(data: data, metricType: metric)
            if let insight = createTrendInsight(from: trendAnalysis, period: period) {
                insights.append(insight)
            }
        }
        
        return insights
    }
    
    private func analyzeTrend(data: [ChartDataPoint], metricType: MetricType) -> TrendAnalysis {
        guard data.count >= 3 else {
            return TrendAnalysis(
                metric: metricType.displayName,
                direction: .stable,
                magnitude: 0,
                timeframe: "insufficient data",
                confidence: 0,
                isSignificant: false
            )
        }
        
       let sortedData = data.sorted { $0.date < $1.date }
       let values: [Double] = sortedData.map { $0.value }
        
        // Simple linear regression
        let n = Double(values.count)
        let x: [Double] = Array(0..<values.count).map { Double($0) }
        let y: [Double] = values
        
        let sumX = x.reduce(0) { $0 + $1 }
        let sumY = y.reduce(0) { $0 + $1 }
        let sumXY = zip(x, y).map(*).reduce(0) { $0 + $1 }
        let sumXX = x.map { $0 * $0 }.reduce(0) { $0 + $1 }
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)
        let intercept = (sumY - slope * sumX) / n
        
        // Calculate R-squared
        let yMean = sumY / n
        let totalSumSquares: Double = y.map { pow($0 - yMean, 2) }.reduce(0.0) { result, value in
            return result + value
        }
       let residualSumSquares: Double = zip(x, y).map { xVal, yVal in
            let predicted = slope * xVal + intercept
            return pow(yVal - predicted, 2)
        }.reduce(0.0) { result, value in
            return result + value
        }
        
        let rSquared = 1 - (residualSumSquares / totalSumSquares)
        let confidence = max(0, min(1, rSquared))
        
        // Determine direction and magnitude
        let direction: TrendAnalysis.TrendDirection
        let magnitude = abs(slope)
        
        if abs(slope) < 0.01 {
            direction = .stable
        } else if slope > 0 {
            direction = metricType == .painLevel ? .declining : .improving
        } else {
            direction = metricType == .painLevel ? .improving : .declining
        }
        
        let isSignificant = confidence > 0.3 && magnitude > 0.05
        
        return TrendAnalysis(
            metric: metricType.displayName,
            direction: direction,
            magnitude: magnitude,
            timeframe: getCurrentTimeframeText(),
            confidence: confidence,
            isSignificant: isSignificant
        )
    }
    
    private func createTrendInsight(from analysis: TrendAnalysis, period: TimePeriod) -> HealthInsight? {
        guard analysis.isSignificant else { return nil }
        
        let title: String
        let description: String
        let priority: InsightPriority
        let actionableText: String?
        
        switch analysis.direction {
        case .improving:
            title = "\(analysis.metric) is improving"
            description = "Your \(analysis.metric.lowercased()) has been \(analysis.direction.displayText) over the \(analysis.timeframe)."
            priority = .medium
            actionableText = "Keep up the great work! Continue your current routine."
            
        case .declining:
            title = "\(analysis.metric) is declining"
            description = "Your \(analysis.metric.lowercased()) has been \(analysis.direction.displayText) over the \(analysis.timeframe)."
            priority = .high
            actionableText = "Consider reviewing your recent activities and identifying potential triggers."
            
        case .stable:
            title = "\(analysis.metric) is stable"
            description = "Your \(analysis.metric.lowercased()) has remained consistent over the \(analysis.timeframe)."
            priority = .low
            actionableText = nil
        }
        
        return HealthInsight(
            type: .trend,
            priority: priority,
            title: title,
            description: description,
            actionableText: actionableText,
            confidence: analysis.confidence,
            relevancePeriod: DateInterval(start: Date().addingTimeInterval(-TimeInterval(period.days * 24 * 60 * 60)), end: Date()),
            associatedMetrics: [analysis.metric],
            generatedAt: Date(),
            isActionable: actionableText != nil
        )
    }
    
    // MARK: - Achievement Insights
    
    private func generateAchievementInsights(period: TimePeriod) async -> [HealthInsight] {
        var insights: [HealthInsight] = []
        let availableMetrics = chartDataManager.getAvailableMetrics()
        
        for metric in availableMetrics {
            let data = chartDataManager.getChartData(for: metric, period: period)
            guard !data.isEmpty else { continue }
            
            if let achievement = detectAchievement(data: data, metricType: metric, period: period) {
                insights.append(achievement)
            }
        }
        
        return insights
    }
    
    private func detectAchievement(data: [ChartDataPoint], metricType: MetricType, period: TimePeriod) -> HealthInsight? {
        guard data.count >= 7 else { return nil }
        
        let sortedData = data.sorted { $0.date < $1.date }
        let recentValues = Array(sortedData.suffix(7)).map { $0.value }
        let allValues = sortedData.map { $0.value }
        
        // Check for consecutive good days
        let threshold = getGoodThreshold(for: metricType)
        let consecutiveGoodDays = getConsecutiveGoodDays(values: recentValues, threshold: threshold, metricType: metricType)
        
        if consecutiveGoodDays >= 3 {
            return HealthInsight(
                type: .achievement,
                priority: .medium,
                title: "\(consecutiveGoodDays)-day streak!",
                description: "You've maintained good \(metricType.displayName.lowercased()) levels for \(consecutiveGoodDays) consecutive days.",
                actionableText: "You're on a roll! Keep up the momentum.",
                confidence: 0.9,
                relevancePeriod: DateInterval(start: Date().addingTimeInterval(-7 * 24 * 60 * 60), end: Date()),
                associatedMetrics: [metricType.displayName],
                generatedAt: Date(),
                isActionable: true
            )
        }
        
        // Check for personal best
        if let recentBest = recentValues.max(),
           let allTimeBest = allValues.max(),
           recentBest >= allTimeBest * 0.95 {
            return HealthInsight(
                type: .achievement,
                priority: .high,
                title: "Personal best \(metricType.displayName.lowercased())!",
                description: "You've reached your highest \(metricType.displayName.lowercased()) level in recent history.",
                actionableText: "Celebrate this milestone and note what contributed to this success.",
                confidence: 0.95,
                relevancePeriod: DateInterval(start: Date().addingTimeInterval(-7 * 24 * 60 * 60), end: Date()),
                associatedMetrics: [metricType.displayName],
                generatedAt: Date(),
                isActionable: true
            )
        }
        
        return nil
    }
    
    private func getGoodThreshold(for metricType: MetricType) -> Double {
        switch metricType {
        case .mood, .energyLevel: return 6.0
        case .painLevel: return 4.0 // Lower pain is better
        case .medicationAdherence: return 80.0
        default: return 5.0
        }
    }
    
    private func getConsecutiveGoodDays(values: [Double], threshold: Double, metricType: MetricType) -> Int {
        var consecutive = 0
        var maxConsecutive = 0
        
        for value in values.reversed() {
            let isGood = metricType == .painLevel ? value <= threshold : value >= threshold
            if isGood {
                consecutive += 1
                maxConsecutive = max(maxConsecutive, consecutive)
            } else {
                break
            }
        }
        
        return maxConsecutive
    }
    
    // MARK: - Pattern Insights
    
    private func generatePatternInsights(period: TimePeriod) async -> [HealthInsight] {
        var insights: [HealthInsight] = []
        let availableMetrics = chartDataManager.getAvailableMetrics()
        
        for metric in availableMetrics {
            let data = chartDataManager.getChartData(for: metric, period: .month)
            guard data.count >= 14 else { continue }
            
            if let pattern = detectWeeklyPattern(data: data, metricType: metric) {
                insights.append(pattern)
            }
        }
        
        return insights
    }
    
    private func detectWeeklyPattern(data: [ChartDataPoint], metricType: MetricType) -> HealthInsight? {
        let calendar = Calendar.current
        var weekdayValues: [Int: [Double]] = [:]
        
        for point in data {
            let weekday = calendar.component(.weekday, from: point.date)
            weekdayValues[weekday, default: []].append(point.value)
        }
        
        let weekdayAverages = weekdayValues.compactMapValues { values in
            values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        }
        
        guard weekdayAverages.count >= 5 else { return nil }
        
        let sortedAverages = weekdayAverages.sorted { $0.value > $1.value }
        let bestDay = sortedAverages.first!
        let worstDay = sortedAverages.last!
        
        let difference = abs(bestDay.value - worstDay.value)
        let averageValue = weekdayAverages.values.reduce(0, +) / Double(weekdayAverages.count)
        let significanceThreshold = averageValue * 0.2
        
        guard difference > significanceThreshold else { return nil }
        
        let bestDayName = getDayName(weekday: bestDay.key)
        let worstDayName = getDayName(weekday: worstDay.key)
        
        return HealthInsight(
            type: .pattern,
            priority: .medium,
            title: "Weekly \(metricType.displayName.lowercased()) pattern detected",
            description: "Your \(metricType.displayName.lowercased()) tends to be best on \(bestDayName) and lowest on \(worstDayName).",
            actionableText: "Plan important activities on \(bestDayName) and take extra care on \(worstDayName).",
            confidence: 0.7,
            relevancePeriod: DateInterval(start: Date().addingTimeInterval(-30 * 24 * 60 * 60), end: Date()),
            associatedMetrics: [metricType.displayName],
            generatedAt: Date(),
            isActionable: true
        )
    }
    
    private func getDayName(weekday: Int) -> String {
        let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return days[weekday - 1]
    }
    
    // MARK: - Correlation Insights
    
    private func generateCorrelationInsights(period: TimePeriod) async -> [HealthInsight] {
        var insights: [HealthInsight] = []
        let availableMetrics = chartDataManager.getAvailableMetrics()
        
        // Check common correlations
        let correlationPairs = [
            (MetricType.mood, MetricType.energyLevel),
            (MetricType.painLevel, MetricType.mood),
            (MetricType.painLevel, MetricType.energyLevel)
        ]
        
        for (metric1, metric2) in correlationPairs {
            guard availableMetrics.contains(metric1) && availableMetrics.contains(metric2) else { continue }
            
            if let correlation = analyzeCorrelation(metric1: metric1, metric2: metric2, period: period) {
                insights.append(correlation)
            }
        }
        
        return insights
    }
    
    private func analyzeCorrelation(metric1: MetricType, metric2: MetricType, period: TimePeriod) -> HealthInsight? {
        let data1 = chartDataManager.getChartData(for: metric1, period: period)
        let data2 = chartDataManager.getChartData(for: metric2, period: period)
        
        guard data1.count >= 5 && data2.count >= 5 else { return nil }
        
        // Align data points by date
        let calendar = Calendar.current
        var alignedPairs: [(Double, Double)] = []
        
        for point1 in data1 {
            if let point2 = data2.first(where: { calendar.isDate($0.date, inSameDayAs: point1.date) }) {
                alignedPairs.append((point1.value, point2.value))
            }
        }
        
        guard alignedPairs.count >= 3 else { return nil }
        
        let correlation = calculatePearsonCorrelation(alignedPairs)
        guard abs(correlation) > 0.4 else { return nil }
        
        let direction = correlation > 0 ? "positively" : "negatively"
        let strength = abs(correlation) > 0.7 ? "strongly" : "moderately"
        
        return HealthInsight(
            type: .correlation,
            priority: .medium,
            title: "\(metric1.displayName) and \(metric2.displayName) are connected",
            description: "Your \(metric1.displayName.lowercased()) and \(metric2.displayName.lowercased()) are \(strength) \(direction) correlated.",
            actionableText: "Focus on improving \(metric1.displayName.lowercased()) to potentially benefit \(metric2.displayName.lowercased()).",
            confidence: abs(correlation),
            relevancePeriod: DateInterval(start: Date().addingTimeInterval(-TimeInterval(period.days * 24 * 60 * 60)), end: Date()),
            associatedMetrics: [metric1.displayName, metric2.displayName],
            generatedAt: Date(),
            isActionable: true
        )
    }
    
    private func calculatePearsonCorrelation(_ pairs: [(Double, Double)]) -> Double {
        let n = Double(pairs.count)
        guard n > 1 else { return 0 }
        
        let x = pairs.map { $0.0 }
        let y = pairs.map { $0.1 }
        
        let sumX = x.reduce(0) { $0 + $1 }
        let sumY = y.reduce(0) { $0 + $1 }
        let meanX = sumX / n
        let meanY = sumY / n
        
        let numerator = zip(x, y).map { (xi, yi) in (xi - meanX) * (yi - meanY) }.reduce(0) { $0 + $1 }
        let denomX = x.map { pow($0 - meanX, 2) }.reduce(0) { $0 + $1 }
        let denomY = y.map { pow($0 - meanY, 2) }.reduce(0) { $0 + $1 }
        
        let denominator = sqrt(denomX * denomY)
        return denominator == 0 ? 0 : numerator / denominator
    }
    
    // MARK: - Warning Insights
    
    private func generateWarningInsights(period: TimePeriod) async -> [HealthInsight] {
        var insights: [HealthInsight] = []
        let availableMetrics = chartDataManager.getAvailableMetrics()
        
        for metric in availableMetrics {
            let data = chartDataManager.getChartData(for: metric, period: .week)
            guard data.count >= 3 else { continue }
            
            if let warning = detectWarning(data: data, metricType: metric) {
                insights.append(warning)
            }
        }
        
        return insights
    }
    
    private func detectWarning(data: [ChartDataPoint], metricType: MetricType) -> HealthInsight? {
        let sortedData = data.sorted { $0.date < $1.date }
        let recentValues = Array(sortedData.suffix(3)).map { $0.value }
        
        // Check for concerning trends
        let isDecreasing = recentValues.count >= 3 && 
                          recentValues[0] > recentValues[1] && 
                          recentValues[1] > recentValues[2]
        
        let isIncreasing = recentValues.count >= 3 && 
                          recentValues[0] < recentValues[1] && 
                          recentValues[1] < recentValues[2]
        
        let shouldWarnOnDecrease = metricType != .painLevel
        let shouldWarnOnIncrease = metricType == .painLevel
        
        if (isDecreasing && shouldWarnOnDecrease) || (isIncreasing && shouldWarnOnIncrease) {
            let trend = (isDecreasing && shouldWarnOnDecrease) ? "declining" : "increasing"
            
            return HealthInsight(
                type: .warning,
                priority: .high,
                title: "\(metricType.displayName) has been \(trend)",
                description: "Your \(metricType.displayName.lowercased()) has been \(trend) for the past 3 days.",
                actionableText: "Consider reviewing recent changes in routine, medications, or activities.",
                confidence: 0.8,
                relevancePeriod: DateInterval(start: Date().addingTimeInterval(-7 * 24 * 60 * 60), end: Date()),
                associatedMetrics: [metricType.displayName],
                generatedAt: Date(),
                isActionable: true
            )
        }
        
        return nil
    }
    
    // MARK: - Recommendation Insights
    
    private func generateRecommendationInsights(period: TimePeriod) async -> [HealthInsight] {
        var insights: [HealthInsight] = []
        
        // Add general recommendations based on available data
        let availableMetrics = chartDataManager.getAvailableMetrics()
        
        if availableMetrics.count < 3 {
            insights.append(HealthInsight(
                type: .recommendation,
                priority: .medium,
                title: "Start tracking more metrics",
                description: "You're currently tracking \(availableMetrics.count) metric(s). Tracking more metrics can provide better insights.",
                actionableText: "Consider adding mood, pain, or energy tracking to get more comprehensive insights.",
                confidence: 0.9,
                relevancePeriod: DateInterval(start: Date(), end: Date().addingTimeInterval(7 * 24 * 60 * 60)),
                associatedMetrics: [],
                generatedAt: Date(),
                isActionable: true
            ))
        }
        
        return insights
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentTimeframeText() -> String {
        switch timePeriodManager.selectedPeriod {
        case .week: return "past week"
        case .month: return "past month"
        case .threeMonth: return "past 3 months"
        case .sixMonth: return "past 6 months"
        case .year: return "past year"
        case .allTime: return "entire tracking period"
        }
    }
}
