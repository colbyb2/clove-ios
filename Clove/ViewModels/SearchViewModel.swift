import Foundation
import SwiftUI

@Observable
class SearchViewModel {
    var searchQuery: String = "" {
        didSet {
            if searchQuery.isEmpty {
                clearResults()
            } else {
                scheduleSearch()
            }
        }
    }

    var searchResults: [SearchResult] = []
    var allResults: [SearchResult] = []
    var isSearching: Bool = false
    var hasSearched: Bool = false
    var categoryFilters = SearchCategoryFilters()

    var currentPage: Int = 0
    var pageSize: Int = 100

    var totalResultCount: Int {
        allResults.count
    }

    var hasMoreResults: Bool {
        searchResults.count < allResults.count
    }

    private var searchTask: Task<Void, Never>?
    private let searchRepo = SearchRepo.shared

    // MARK: - Search Methods

    func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearResults()
            return
        }

        isSearching = true

        Task { @MainActor in
            let results = await searchInBackground()
            self.allResults = results
            self.currentPage = 0
            self.searchResults = Array(results.prefix(pageSize))
            self.isSearching = false
            self.hasSearched = true
        }
    }

    func scheduleSearch() {
        // Cancel previous search
        searchTask?.cancel()

        // Schedule new search with debouncing
        searchTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            performSearch()
        }
    }

    private func searchInBackground() async -> [SearchResult] {
        await Task.detached {
            self.searchRepo.searchLogs(
                query: self.searchQuery,
                filters: self.categoryFilters
            )
        }.value
    }

    // MARK: - Pagination

    func loadMoreResults() {
        guard hasMoreResults else { return }

        currentPage += 1
        let startIndex = currentPage * pageSize
        let endIndex = min(startIndex + pageSize, allResults.count)

        searchResults.append(contentsOf: allResults[startIndex..<endIndex])
    }

    // MARK: - Filter Management

    func toggleCategory(_ category: SearchCategory) {
        categoryFilters.toggle(category)

        // Re-run search if query exists
        if !searchQuery.isEmpty {
            performSearch()
        }
    }

    // MARK: - Clear

    func clearSearch() {
        searchQuery = ""
        clearResults()
    }

    private func clearResults() {
        searchResults = []
        allResults = []
        isSearching = false
        hasSearched = false
        currentPage = 0
    }
}
