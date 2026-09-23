import Foundation

/// Protocol defining operations for searching across logs
protocol SearchRepositoryProtocol {
    /// Searches local health records using an explicit, inspectable request.
    func search(request: SearchRequest) -> [SearchResult]

    /// Searches notes for a query
    /// - Parameter query: The search query
    /// - Returns: Array of search results
    func searchNotes(query: String) -> [SearchResult]

    /// Searches symptoms for a query
    /// - Parameter query: The search query
    /// - Returns: Array of search results
    func searchSymptoms(query: String) -> [SearchResult]

    /// Searches meals for a query
    /// - Parameter query: The search query
    /// - Returns: Array of search results
    func searchMeals(query: String) -> [SearchResult]

    /// Searches activities for a query
    /// - Parameter query: The search query
    /// - Returns: Array of search results
    func searchActivities(query: String) -> [SearchResult]

    /// Searches medications for a query
    /// - Parameter query: The search query
    /// - Returns: Array of search results
    func searchMedications(query: String) -> [SearchResult]

    /// Searches bowel movements for a query
    /// - Parameter query: The search query
    /// - Returns: Array of search results
    func searchBowelMovements(query: String) -> [SearchResult]
}

extension SearchRepositoryProtocol {
    /// Compatibility entry point for older callers.
    func searchLogs(query: String, filters: SearchCategoryFilters) -> [SearchResult] {
        search(request: SearchRequest(query: query, categories: filters.categories))
    }
}
