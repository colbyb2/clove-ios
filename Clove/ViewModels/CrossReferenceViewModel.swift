import SwiftUI

@Observable
class CrossReferenceViewModel {
    // MARK: - Dependencies
    private let metricRegistry: MetricRegistryProtocol
    private let timePeriodManager: TimePeriodManaging

    // MARK: - State
    var primaryMetric: (any MetricProvider)?
    var secondaryMetric: (any MetricProvider)?
    var currentAnalysis: CorrelationAnalysis?
    var isCalculating: Bool = false
    var savedCorrelations: [MetricPair] = []
    var suggestedPairs: [MetricPair] = []
    var availableMetrics: [any MetricProvider] = []
    var errorMessage: String?
    var calculationStep: String?
    var currentCalculationStepIndex: Int = 0

    // MARK: - Initialization

    /// Convenience initializer using production singletons
    convenience init() {
        self.init(
            metricRegistry: MetricRegistry.shared,
            timePeriodManager: TimePeriodManager.shared
        )
    }

    /// Designated initializer with full dependency injection
    init(
        metricRegistry: MetricRegistryProtocol,
        timePeriodManager: TimePeriodManaging
    ) {
        self.metricRegistry = metricRegistry
        self.timePeriodManager = timePeriodManager

        Task {
            await loadAvailableMetrics()
            await loadSuggestedCorrelations()
        }
        loadSavedCorrelations()
    }

    /// Preview factory with mock dependencies
    static func preview() -> CrossReferenceViewModel {
        return CrossReferenceViewModel(
            metricRegistry: MockMetricRegistry(),
            timePeriodManager: MockTimePeriodManager()
        )
    }
    
    func calculateCorrelation(primary: any MetricProvider, secondary: any MetricProvider) {
        guard primary.id != secondary.id else {
            errorMessage = "Cannot analyze the same metric against itself. Please choose two different metrics to compare."
            return
        }

        isCalculating = true
        errorMessage = nil
        currentCalculationStepIndex = 0
        calculationStep = "Starting analysis..."

        Task { @MainActor in
            do {
                let analysis = try await performCorrelationAnalysis(primary: primary, secondary: secondary)
                self.currentAnalysis = analysis
                self.primaryMetric = primary
                self.secondaryMetric = secondary
            } catch {
                // Use the localized description from the error
                if let localizedError = error as? LocalizedError,
                   let description = localizedError.errorDescription {
                    self.errorMessage = description
                } else {
                    self.errorMessage = error.localizedDescription
                }
            }
            self.isCalculating = false
            self.calculationStep = nil
            self.currentCalculationStepIndex = 0
        }
    }
    
    func selectMetric(id: String, isPrimary: Bool) async {
        if let metric = await metricRegistry.getMetric(id: id) {
            await MainActor.run {
                if isPrimary {
                    self.primaryMetric = metric
                } else {
                    self.secondaryMetric = metric
                }
                
                // Auto-calculate if both metrics are selected
                if let primary = self.primaryMetric, let secondary = self.secondaryMetric {
                    self.calculateCorrelation(primary: primary, secondary: secondary)
                }
            }
        } else {
            await MainActor.run {
                self.errorMessage = "Unable to load the selected metric. Please try again or choose a different metric."
            }
        }
    }
    
    func saveCorrelation(_ analysis: CorrelationAnalysis) {
        let pair = MetricPair(
            primary: analysis.primaryMetric,
            secondary: analysis.secondaryMetric,
            correlationStrength: analysis.coefficient,
            lastAnalyzed: Date()
        )
        
        // Remove existing pair if it exists
        savedCorrelations.removeAll { $0.primary.id == pair.primary.id && $0.secondary.id == pair.secondary.id }
        
        // Add new pair
        savedCorrelations.append(pair)
        
        // Save to UserDefaults
        savePairsToUserDefaults()
    }
    
    func removeSavedCorrelation(_ pair: MetricPair) {
        savedCorrelations.removeAll { $0.id == pair.id }
        savePairsToUserDefaults()
    }
    
    func loadSavedCorrelation(_ pair: MetricPair) {
        calculateCorrelation(primary: pair.primary, secondary: pair.secondary)
    }
    
    private func loadAvailableMetrics() async {
        let metrics = await metricRegistry.getAllAvailableMetrics()
        await MainActor.run {
            self.availableMetrics = metrics
        }
    }
    
    
    private func performCorrelationAnalysis(primary: any MetricProvider, secondary: any MetricProvider) async throws -> CorrelationAnalysis {
        let period = timePeriodManager.selectedPeriod

        // Step 1: Fetching data
        await updateCalculationStep(index: 0, message: "Fetching data for \(primary.displayName)...")
        let primaryDataPoints = await primary.getDataPoints(for: period)

        await updateCalculationStep(index: 0, message: "Fetching data for \(secondary.displayName)...")
        let secondaryDataPoints = await secondary.getDataPoints(for: period)
        
        // Step 2: Processing data
        await updateCalculationStep(index: 1, message: "Processing and aligning data points...")

        // Pre-aggregate count-based metrics (like bowel movements) by day
        let primaryData: [(Date, Double)]
        if case .count = primary.dataType {
            primaryData = aggregateCountData(primaryDataPoints)
        } else {
            primaryData = primaryDataPoints.map { ($0.date, $0.value) }
        }

        let secondaryData: [(Date, Double)]
        if case .count = secondary.dataType {
            secondaryData = aggregateCountData(secondaryDataPoints)
        } else {
            secondaryData = secondaryDataPoints.map { ($0.date, $0.value) }
        }

        // Align data points by date
        let alignedData = alignDataPoints(primary: primaryData, secondary: secondaryData)
        
        guard alignedData.count >= 3 else {
            throw CorrelationError.insufficientData
        }

        // Step 3: Calculating correlation
        await updateCalculationStep(index: 2, message: "Calculating Pearson correlation coefficient...")

        let coefficient = calculatePearsonCorrelation(alignedData)
        let pValue = calculatePValue(alignedData, coefficient: coefficient)
        let significance = 1 - pValue

        // Step 4: Generating insights
        await updateCalculationStep(index: 3, message: "Generating insights and patterns...")

        let insights = generateCorrelationInsights(
            primaryMetric: primary,
            secondaryMetric: secondary,
            coefficient: coefficient,
            dataPoints: alignedData
        )
        
        // Create time range
        let dates = alignedData.map { $0.0 }
        let timeRange = DateInterval(start: dates.min() ?? Date(), end: dates.max() ?? Date())
        
        return CorrelationAnalysis(
            primaryMetric: primary,
            secondaryMetric: secondary,
            coefficient: coefficient,
            significance: significance,
            pValue: pValue,
            dataPoints: alignedData,
            timeRange: timeRange,
            strengthDescription: getStrengthDescription(coefficient),
            insights: insights
        )
    }
    
    
    private func aggregateCountData(_ dataPoints: [MetricDataPoint]) -> [(Date, Double)] {
        let calendar = Calendar.current
        
        // Group data points by day
        let groupedByDay = Dictionary(grouping: dataPoints) { point in
            calendar.startOfDay(for: point.date)
        }
        
        // Count entries per day
        return groupedByDay.map { (date, points) in
            (date, Double(points.count))
        }.sorted { $0.0 < $1.0 }
    }
    
    private func alignDataPoints(primary: [(Date, Double)], secondary: [(Date, Double)]) -> [(Date, Double, Double)] {
        var aligned: [(Date, Double, Double)] = []
        let calendar = Calendar.current
        
        for (primaryDate, primaryValue) in primary {
            // Find matching secondary value (same day)
            if let secondaryItem = secondary.first(where: {
                calendar.isDate($0.0, inSameDayAs: primaryDate)
            }) {
                aligned.append((primaryDate, primaryValue, secondaryItem.1))
            }
        }
        
        return aligned.sorted { $0.0 < $1.0 }
    }
    
    private func calculatePearsonCorrelation(_ data: [(Date, Double, Double)]) -> Double {
        let n = Double(data.count)
        guard n > 1 else { return 0 }
        
        let xValues = data.map { $0.1 }
        let yValues = data.map { $0.2 }
        
        let xSum = xValues.reduce(0, +)
        let ySum = yValues.reduce(0, +)
        let xMean = xSum / n
        let yMean = ySum / n
        
        let numerator = zip(xValues, yValues).map { (x, y) in
            (x - xMean) * (y - yMean)
        }.reduce(0, +)
        
        let xVariance = xValues.map { pow($0 - xMean, 2) }.reduce(0, +)
        let yVariance = yValues.map { pow($0 - yMean, 2) }.reduce(0, +)
        
        let denominator = sqrt(xVariance * yVariance)
        
        guard denominator != 0 else { return 0 }
        
        return numerator / denominator
    }
    
    private func calculatePValue(_ data: [(Date, Double, Double)], coefficient: Double) -> Double {
        let n = Double(data.count)
        guard n > 2 else { return 1.0 }
        
        let t = coefficient * sqrt((n - 2) / (1 - coefficient * coefficient))
        
        // Simplified p-value calculation (approximation)
        // In a real implementation, you'd use a proper t-distribution function
        let absT = abs(t)
        if absT > 2.576 { return 0.01 }  // 99% confidence
        if absT > 1.96 { return 0.05 }   // 95% confidence
        if absT > 1.645 { return 0.10 }  // 90% confidence
        return 0.20
    }
    
    private func getStrengthDescription(_ coefficient: Double) -> String {
        let absCoeff = abs(coefficient)
        switch absCoeff {
        case 0.8...1.0: return "Very Strong"
        case 0.6..<0.8: return "Strong"
        case 0.4..<0.6: return "Moderate"
        case 0.2..<0.4: return "Weak"
        default: return "Very Weak"
        }
    }
    
    private func generateCorrelationInsights(
        primaryMetric: any MetricProvider,
        secondaryMetric: any MetricProvider,
        coefficient: Double,
        dataPoints: [(Date, Double, Double)]
    ) -> [String] {
        var insights: [String] = []
        
        let direction = coefficient > 0 ? "increase" : "decrease"
        let strength = getStrengthDescription(coefficient)
        let absCoeff = abs(coefficient)
        
        // Primary insight
        if absCoeff > 0.3 {
            insights.append("When \(primaryMetric.displayName) increases, \(secondaryMetric.displayName) tends to \(direction)")
        }
        
        // Strength insight
        if absCoeff > 0.5 {
            insights.append("This \(strength.lowercased()) correlation suggests a meaningful relationship")
        }
        
        // Data quality insight
        insights.append("Analysis based on \(dataPoints.count) matching data points")
        
        // Actionable insight
        if absCoeff > 0.4 {
            if coefficient > 0 {
                insights.append("Improving \(primaryMetric.displayName) may positively impact \(secondaryMetric.displayName)")
            } else {
                insights.append("Changes in \(primaryMetric.displayName) may inversely affect \(secondaryMetric.displayName)")
            }
        }
        
        return insights
    }
    
    private func loadSuggestedCorrelations() async {
        // Generate suggested correlations based on common health patterns
        let commonPairs = [
            ("mood", "pain_level"),
            ("energy_level", "mood"),
            ("pain_level", "energy_level"),
            ("medication_adherence", "mood"),
            ("medication_adherence", "pain_level")
        ]
        
        var pairs: [MetricPair] = []
        
        for (primaryId, secondaryId) in commonPairs {
            if let primaryMetric = await metricRegistry.getMetric(id: primaryId),
               let secondaryMetric = await metricRegistry.getMetric(id: secondaryId) {
                let pair = MetricPair(
                    primary: primaryMetric,
                    secondary: secondaryMetric,
                    correlationStrength: 0.0,
                    lastAnalyzed: Date()
                )
                pairs.append(pair)
            }
        }
        
        await MainActor.run {
            self.suggestedPairs = pairs
        }
    }
    
    private func loadSavedCorrelations() {
        // Load from UserDefaults in a real implementation
        savedCorrelations = []
    }
    
    private func savePairsToUserDefaults() {
        // Save to UserDefaults in a real implementation
    }

    @MainActor
    private func updateCalculationStep(index: Int, message: String) async {
        self.currentCalculationStepIndex = index
        self.calculationStep = message
        // Small delay to ensure UI updates and user can see the step
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
    }
}
