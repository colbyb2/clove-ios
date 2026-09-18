import SwiftUI

// MARK: - Metric Explorer View Model

@Observable
class MetricExplorerViewModel {
    var searchText: String = ""
    var selectedCategory: MetricCategory? = nil
    var metricSummaries: [MetricSummary] = []
    var isLoading = false
    var errorMessage: String?
    private var symptomDisplayOrder: [String: Int] = [:]
    
    private let metricRegistry = MetricRegistry.shared
    
    init() {
        Task {
            await loadMetricSummaries()
        }
    }
    
    @MainActor
    func loadMetricSummaries() async {
        isLoading = true
        errorMessage = nil
        
        let summaries = await metricRegistry.getMetricSummaries()
        self.metricSummaries = summaries
        self.symptomDisplayOrder = Dictionary(uniqueKeysWithValues: SymptomsRepo.shared.getTrackedSymptoms().map {
            ($0.name.lowercased(), $0.displayOrder)
        })
        
        isLoading = false
    }
    
    func filteredMetrics() -> [MetricSummary] {
        var filtered = metricSummaries
        
        // Filter by category if selected
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { metric in
                metric.displayName.localizedCaseInsensitiveContains(searchText) ||
                metric.description.localizedCaseInsensitiveContains(searchText) ||
                metric.category.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort by availability first, then by name
        return filtered.sorted { metric1, metric2 in
            if metric1.isAvailable != metric2.isAvailable {
                return metric1.isAvailable && !metric2.isAvailable
            }
            if metric1.category == .symptoms, metric2.category == .symptoms {
                let firstOrder = symptomDisplayOrder[metric1.displayName.lowercased()] ?? .max
                let secondOrder = symptomDisplayOrder[metric2.displayName.lowercased()] ?? .max
                if firstOrder != secondOrder { return firstOrder < secondOrder }
            }
            return metric1.displayName < metric2.displayName
        }
    }
    
    func refresh() async {
        metricRegistry.invalidateSummaryCache()
        await loadMetricSummaries()
    }
}
