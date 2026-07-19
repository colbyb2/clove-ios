import Foundation
import SwiftUI

// MARK: - Metric Registry

/// Central registry that manages all available metrics and provides efficient data access
@Observable
class MetricRegistry {
    static let shared = MetricRegistry()
    
    // MARK: - Private Properties
    
    private var cachedMetrics: [String: any MetricProvider] = [:]
    private var cachedSummaries: [MetricSummary] = []
    private var lastCacheUpdate: Date = .distantPast
    private var lastSummaryUpdate: Date = .distantPast
    private let cacheExpiry: TimeInterval = 300 // 5 minutes
    private let summaryExpiry: TimeInterval = 60 // 1 minute for summaries
    
    // Static metrics that are always available
    private let staticMetrics: [any MetricProvider] = [
        MoodMetricProvider(),
        PainLevelMetricProvider(),
        EnergyLevelMetricProvider(),
        HydrationMetricProvider(),
        FlareDayMetricProvider(),
        MedicationAdherenceMetricProvider(),
        WeatherMetricProvider(),
        ActivityCountMetricProvider(),
        MealCountMetricProvider(),
        BowelMovementMetricProvider(),
        FlowLevelMetricProvider()
    ]
    
    private init() {
#if DEBUG
        MetricSemanticsContractChecks.assertAllPass()
        MetricCatalogContractChecks.assertAllPass()
        MetricObservationContractChecks.assertAllPass()
        MetricObservationAdapterChecks.assertAllPass()
        AnalyticsRepositoryContractChecks.assertAllPass()
        MetricCatalogCompatibilityChecks.assertAllProvidersMapped(staticMetrics)
#endif
    }
    
    // MARK: - Public Methods
    
    /// Get summaries of all available metrics (optimized for UI display)
    func getMetricSummaries() async -> [MetricSummary] {
        // Check if summaries cache is still valid
        if Date().timeIntervalSince(lastSummaryUpdate) < summaryExpiry && !cachedSummaries.isEmpty {
            return cachedSummaries
        }
        
        await refreshMetricSummaries()
        return cachedSummaries
    }
    
    /// Get summaries filtered by category
    func getMetricSummaries(for category: MetricCategory) async -> [MetricSummary] {
        let allSummaries = await getMetricSummaries()
        return allSummaries.filter { $0.category == category }
    }
    
    /// Get all available metrics with full data access
    func getAllAvailableMetrics() async -> [any MetricProvider] {
        // Check cache validity
        if Date().timeIntervalSince(lastCacheUpdate) < cacheExpiry && !cachedMetrics.isEmpty {
            return Array(cachedMetrics.values)
        }
        
        await refreshMetricCache()
        return Array(cachedMetrics.values)
    }
    
    /// Get a specific metric by ID
    func getMetric(id: String) async -> (any MetricProvider)? {
        // Check if metric is already cached
        if let cached = cachedMetrics[id] {
            return cached
        }
        
        // If not cached, refresh and try again
        await refreshMetricCache()
        return cachedMetrics[id]
    }
    
    /// Get metrics by category
    func getMetrics(for category: MetricCategory) async -> [any MetricProvider] {
        let allMetrics = await getAllAvailableMetrics()
        return allMetrics.filter { $0.category == category }
    }
    
    /// Clear all caches (call when new data is logged)
    func invalidateCache() {
        cachedMetrics.removeAll()
        cachedSummaries.removeAll()
        lastCacheUpdate = .distantPast
        lastSummaryUpdate = .distantPast
    }
    
    /// Clear only summary cache (lighter invalidation)
    func invalidateSummaryCache() {
        cachedSummaries.removeAll()
        lastSummaryUpdate = .distantPast
    }
    
    // MARK: - Private Methods
    
    private func refreshMetricSummaries() async {
        var summaries: [MetricSummary] = []
        let allMetrics = await getAllMetricProviders()
        let interval = TimePeriodManager.shared.currentDateRange
            ?? AnalyticsDateRangeFactory().interval(for: TimePeriodManager.shared.selectedPeriod)
        guard let dataset = try? await AnalyticsRepositoryContainer.shared.load(
            AnalyticsRequest(interval: interval, includeRawEvents: false),
            granularity: AnalyticsChartPipeline().granularity(for: interval)
        ) else {
            cachedSummaries = []
            lastSummaryUpdate = Date()
            return
        }

        for metric in allMetrics {
            let summaryValues = MetricSummaryObservationFormatter.summarize(
                metric: metric,
                observations: observations(for: metric, in: dataset)
            )
            let summary = MetricSummary(
                id: metric.id,
                displayName: metric.displayName,
                description: metric.description,
                icon: metric.icon,
                category: metric.category,
                dataPointCount: summaryValues.observedCount,
                lastValue: summaryValues.lastValue,
                isAvailable: summaryValues.observedCount > 0,
                isActive: metric.category == .symptoms ? (metric as! SymptomMetricProvider).isActive : nil
            )
            
            summaries.append(summary)
        }
        
        // Filter to only metrics with data
        cachedSummaries = summaries.filter { $0.isAvailable }
        lastSummaryUpdate = Date()
    }
    
    private func refreshMetricCache() async {
        let allMetrics = await getAllMetricProviders()
        let interval = AnalyticsDateRangeFactory().interval(for: .allTime)
        guard let dataset = try? await AnalyticsRepositoryContainer.shared.load(
            AnalyticsRequest(interval: interval, includeRawEvents: false), granularity: .monthly
        ) else {
            cachedMetrics = [:]
            lastCacheUpdate = Date()
            return
        }
        var validMetrics: [String: any MetricProvider] = [:]
        for metric in allMetrics {
            if !observations(for: metric, in: dataset).isEmpty {
                validMetrics[metric.id] = metric
            }
        }
        
        cachedMetrics = validMetrics
        lastCacheUpdate = Date()
    }

    private func observations(for provider: any MetricProvider, in dataset: AnalyticsDataset) -> [MetricObservation] {
        if let definition = provider.catalogMetricDefinition {
            let direct = dataset.observations(for: definition.id)
            if !direct.isEmpty { return direct }
        }
        let direct = dataset.observations(for: MetricID(rawValue: provider.id))
        if !direct.isEmpty { return direct }
        guard let aliases = dataset.metricAliases[provider.id], aliases.count == 1, let canonical = aliases.first else { return [] }
        return dataset.observations(for: canonical)
    }
    
    /// Get all possible metric providers (both static and dynamic)
    private func getAllMetricProviders() async -> [any MetricProvider] {
        var metrics: [any MetricProvider] = staticMetrics
        
        // Add dynamically generated metrics
        metrics.append(contentsOf: await generateCoreHealthMetrics())
        metrics.append(contentsOf: await generateSymptomMetrics())
        metrics.append(contentsOf: await generateMedicationMetrics())
        metrics.append(contentsOf: await generateActivityMetrics())
        metrics.append(contentsOf: await generateMealMetrics())

#if DEBUG
        MetricCatalogCompatibilityChecks.assertAllProvidersMapped(metrics)
#endif
        
        return metrics
    }
    
    // MARK: - Metric Generation Methods
    
    private func generateCoreHealthMetrics() async -> [any MetricProvider] {
        // Core health metrics are handled by staticMetrics
        return []
    }
    
    private func generateSymptomMetrics() async -> [any MetricProvider] {
        // Generate metrics for tracked symptoms
        let symptomsRepo = SymptomsRepo.shared
        let dataLoader = OptimizedDataLoader.shared
        let symptoms: [String:Bool] = await dataLoader.getAvailableSymptoms()
        let trackedSymptoms = symptomsRepo.getTrackedSymptoms()

        return symptoms.map { (symptomName, isBinary) in
            let isActive = trackedSymptoms.filter( { $0.name.lowercased() == symptomName.lowercased() }).count > 0
            return SymptomMetricProvider(symptomName: symptomName, isActive: isActive, isBinary: isBinary)
        }
    }
    
    private func generateMedicationMetrics() async -> [any MetricProvider] {
        // Generate metrics for tracked medications
        let dataLoader = OptimizedDataLoader.shared
        let medications = await dataLoader.getAvailableMedications()
        
        return medications.map { medication in
            MedicationMetricProvider(medicationName: medication)
        }
    }
    
    private func generateActivityMetrics() async -> [any MetricProvider] {
        // Generate metrics for tracked activities
        let dataLoader = OptimizedDataLoader.shared
        let activities = await dataLoader.getAvailableActivities()
        
        return activities.map { activity in
            ActivityMetricProvider(activityName: activity)
        }
    }
    
    private func generateMealMetrics() async -> [any MetricProvider] {
        // Generate metrics for tracked meals
        let dataLoader = OptimizedDataLoader.shared
        let meals = await dataLoader.getAvailableMeals()
        
        return meals.map { meal in
            MealMetricProvider(mealName: meal)
        }
    }
}

struct MetricSummaryObservationValues: Equatable {
    let observedCount: Int
    let lastValue: String?
}

enum MetricSummaryObservationFormatter {
    static func summarize(
        metric: any MetricProvider,
        observations: [MetricObservation]
    ) -> MetricSummaryObservationValues {
        let observed = observations.compactMap { observation -> (Date, MetricObservedValue)? in
            guard case .observed(let value) = observation.state else { return nil }
            return (observation.timestamp, value)
        }
        let latest = observed.max { $0.0 < $1.0 }?.1
        return MetricSummaryObservationValues(
            observedCount: observed.count,
            lastValue: latest.flatMap { format($0, metric: metric) }
        )
    }

    private static func format(_ value: MetricObservedValue, metric: any MetricProvider) -> String? {
        if let number = value.numericValue { return metric.formatValue(number) }
        switch value {
        case .category(let category):
            return category
        case .distribution(let buckets):
            let total = buckets.reduce(0) { $0 + $1.count }
            if buckets.count == 1, let bucket = buckets.first,
               let number = Double(bucket.value.replacingOccurrences(of: "number:", with: "")) {
                return metric.formatValue(number)
            }
            return total > 0 ? "\(total) recorded" : nil
        case .number, .boolean, .ratio:
            return nil
        }
    }
}

// MARK: - Convenience Extensions

extension MetricRegistry {
    /// Quick check if a specific metric is available
    func hasMetric(id: String) async -> Bool {
        let summaries = await getMetricSummaries()
        return summaries.contains { $0.id == id }
    }
    
    /// Get count of available metrics
    func getAvailableMetricCount() async -> Int {
        let summaries = await getMetricSummaries()
        return summaries.count
    }
    
    /// Get count of metrics by category
    func getMetricCount(for category: MetricCategory) async -> Int {
        let summaries = await getMetricSummaries(for: category)
        return summaries.count
    }
}
