import SwiftUI

// MARK: - Metric Explorer View Model

@Observable
class MetricExplorerViewModel {
    var searchText: String = ""
    var selectedCategory: MetricCategory? = nil
    var metricSummaries: [MetricSummary] = []
    var isLoading = false
    var errorMessage: String?
    
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
        
        do {
            let summaries = await metricRegistry.getMetricSummaries()
            self.metricSummaries = summaries
        } catch {
            self.errorMessage = "Failed to load metrics: \(error.localizedDescription)"
        }
        
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
            return metric1.displayName < metric2.displayName
        }
    }
    
    func refresh() async {
        metricRegistry.invalidateSummaryCache()
        await loadMetricSummaries()
    }
}