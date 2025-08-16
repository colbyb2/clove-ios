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
        FlareDayMetricProvider(),
        MedicationAdherenceMetricProvider(),
        WeatherMetricProvider(),
        ActivityCountMetricProvider(),
        MealCountMetricProvider()
    ]
    
    private init() {}
    
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
        
        // Get all available metrics
        let allMetrics = await getAllMetricProviders()
        
        // Create summaries efficiently (only count and last value, not full data)
        for metric in allMetrics {
            let dataPointCount = await metric.getDataPointCount()
            let lastValue = await metric.getLastValue()
            
            let summary = MetricSummary(
                id: metric.id,
                displayName: metric.displayName,
                description: metric.description,
                icon: metric.icon,
                category: metric.category,
                dataPointCount: dataPointCount,
                lastValue: lastValue?.formattedValue,
                isAvailable: dataPointCount > 0
            )
            
            summaries.append(summary)
        }
        
        // Filter to only metrics with data
        cachedSummaries = summaries.filter { $0.isAvailable }
        lastSummaryUpdate = Date()
    }
    
    private func refreshMetricCache() async {
        let allMetrics = await getAllMetricProviders()
        
        // Filter to only metrics that have data
        var validMetrics: [String: any MetricProvider] = [:]
        
        for metric in allMetrics {
            let dataCount = await metric.getDataPointCount()
            if dataCount > 0 {
                validMetrics[metric.id] = metric
            }
        }
        
        cachedMetrics = validMetrics
        lastCacheUpdate = Date()
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
        let symptoms = symptomsRepo.getTrackedSymptoms()
        
        return symptoms.map { symptom in
            SymptomMetricProvider(symptomName: symptom.name)
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
