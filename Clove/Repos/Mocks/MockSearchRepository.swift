import Foundation

/// Mock implementation of SearchRepositoryProtocol for testing and previews
final class MockSearchRepository: SearchRepositoryProtocol {
    /// Pre-configured search results to return
    var mockResults: [SearchResult] = []

    /// Controls whether operations succeed or fail
    var shouldSucceed: Bool = true

    func searchLogs(query: String, filters: SearchCategoryFilters) -> [SearchResult] {
        if shouldSucceed {
            return mockResults
        }
        return []
    }

    func searchNotes(query: String) -> [SearchResult] {
        if shouldSucceed {
            return mockResults.filter { $0.matchedCategory == .notes }
        }
        return []
    }

    func searchSymptoms(query: String) -> [SearchResult] {
        if shouldSucceed {
            return mockResults.filter { $0.matchedCategory == .symptoms }
        }
        return []
    }

    func searchMeals(query: String) -> [SearchResult] {
        if shouldSucceed {
            return mockResults.filter { $0.matchedCategory == .meals }
        }
        return []
    }

    func searchActivities(query: String) -> [SearchResult] {
        if shouldSucceed {
            return mockResults.filter { $0.matchedCategory == .activities }
        }
        return []
    }

    func searchMedications(query: String) -> [SearchResult] {
        if shouldSucceed {
            return mockResults.filter { $0.matchedCategory == .medications }
        }
        return []
    }

    func searchBowelMovements(query: String) -> [SearchResult] {
        if shouldSucceed {
            return mockResults.filter { $0.matchedCategory == .bowelMovements }
        }
        return []
    }
}
