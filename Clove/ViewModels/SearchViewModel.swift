import Foundation
import SwiftUI

@Observable
final class SearchViewModel {
    private let searchRepository: SearchRepositoryProtocol
    private let defaults: UserDefaults
    private let recentSearchesKey = "clove.search.recentQueries"
    private var searchTask: Task<Void, Never>?

    var request = SearchRequest()
    var availableCategories = SearchCategory.allCases
    var searchResults: [SearchResult] = []
    var allResults: [SearchResult] = []
    var recentSearches: [String] = []
    var isSearching = false
    var hasSearched = false
    var currentPage = 0
    let pageSize = 50

    var searchQuery: String {
        get { request.query }
        set {
            request.query = newValue
            if request.normalizedQuery.isEmpty {
                clearResults()
            } else {
                scheduleSearch()
            }
        }
    }

    var totalResultCount: Int { allResults.count }
    var hasMoreResults: Bool { searchResults.count < allResults.count }
    var selectedAllCategories: Bool {
        !availableCategories.isEmpty && request.categories == Set(availableCategories)
    }
    var activeRefinementCount: Int {
        (request.dateRange == .allTime ? 0 : 1) + (request.sortOrder == .newestFirst ? 0 : 1)
    }

    convenience init() {
        self.init(searchRepository: SearchRepo.shared)
    }

    init(searchRepository: SearchRepositoryProtocol, defaults: UserDefaults = .standard) {
        self.searchRepository = searchRepository
        self.defaults = defaults
        recentSearches = defaults.stringArray(forKey: recentSearchesKey) ?? []
    }

    static func preview() -> SearchViewModel {
        SearchViewModel(searchRepository: MockDependencyContainer().searchRepository)
    }

    func setAvailableCategories(_ categories: [SearchCategory]) {
        availableCategories = categories
        let allowed = Set(categories)
        let retained = request.categories.intersection(allowed)
        request.categories = retained.isEmpty ? allowed : retained
    }

    func performSearch(recordInHistory: Bool = false) {
        let submittedRequest = request
        guard !submittedRequest.normalizedQuery.isEmpty else {
            clearResults()
            return
        }

        searchTask?.cancel()
        isSearching = true
        if recordInHistory {
            rememberSearch(submittedRequest.normalizedQuery)
        }

        Task { @MainActor in
            let results = await Task.detached {
                self.searchRepository.search(request: submittedRequest)
            }.value
            guard submittedRequest == self.request else { return }
            self.allResults = results
            self.currentPage = 0
            self.searchResults = Array(results.prefix(self.pageSize))
            self.isSearching = false
            self.hasSearched = true
        }
    }

    func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            performSearch()
        }
    }

    func submitSearch() {
        performSearch(recordInHistory: true)
    }

    func useSuggestion(_ query: String) {
        request.query = query
        performSearch(recordInHistory: true)
    }

    func loadMoreResults() {
        guard hasMoreResults else { return }
        currentPage += 1
        let startIndex = currentPage * pageSize
        let endIndex = min(startIndex + pageSize, allResults.count)
        guard startIndex < endIndex else { return }
        searchResults.append(contentsOf: allResults[startIndex..<endIndex])
    }

    func selectAllCategories() {
        request.categories = Set(availableCategories)
        refreshForFilterChange()
    }

    func toggleCategory(_ category: SearchCategory) {
        if selectedAllCategories {
            request.categories = [category]
        } else if request.categories.contains(category) {
            request.categories.remove(category)
            if request.categories.isEmpty {
                request.categories = Set(availableCategories)
            }
        } else {
            request.categories.insert(category)
        }
        refreshForFilterChange()
    }

    func applyRefinements(
        dateRange: SearchDateRange,
        customStartDate: Date?,
        customEndDate: Date?,
        sortOrder: SearchSortOrder
    ) {
        request.dateRange = dateRange
        request.customStartDate = customStartDate
        request.customEndDate = customEndDate
        request.sortOrder = sortOrder
        refreshForFilterChange()
    }

    func resetRefinements() {
        applyRefinements(
            dateRange: .allTime,
            customStartDate: nil,
            customEndDate: nil,
            sortOrder: .newestFirst
        )
    }

    func removeRecentSearch(_ query: String) {
        recentSearches.removeAll { $0.localizedCaseInsensitiveCompare(query) == .orderedSame }
        defaults.set(recentSearches, forKey: recentSearchesKey)
    }

    func clearRecentSearches() {
        recentSearches = []
        defaults.removeObject(forKey: recentSearchesKey)
    }

    func clearSearch() {
        request.query = ""
        clearResults()
    }

    private func refreshForFilterChange() {
        if request.normalizedQuery.isEmpty {
            clearResults()
        } else {
            performSearch()
        }
    }

    private func rememberSearch(_ query: String) {
        recentSearches.removeAll { $0.localizedCaseInsensitiveCompare(query) == .orderedSame }
        recentSearches.insert(query, at: 0)
        recentSearches = Array(recentSearches.prefix(5))
        defaults.set(recentSearches, forKey: recentSearchesKey)
    }

    private func clearResults() {
        searchTask?.cancel()
        searchResults = []
        allResults = []
        isSearching = false
        hasSearched = false
        currentPage = 0
    }
}
