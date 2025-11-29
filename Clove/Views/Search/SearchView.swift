import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    @State private var selectedLog: DailyLog?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Category filters section
                categoryFiltersSection

                // Results count (if applicable)
                if !viewModel.searchResults.isEmpty {
                    resultCountHeader
                }

                // Main content
                if viewModel.isSearching {
                    loadingState
                } else if viewModel.searchQuery.isEmpty {
                    initialEmptyState
                } else if viewModel.searchResults.isEmpty && viewModel.hasSearched {
                    noResultsState
                } else if !viewModel.searchResults.isEmpty {
                    resultsListSection
                } else {
                    // Temporary state while debouncing (query exists but search hasn't run yet)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $viewModel.searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search your logs..."
            )
            .sheet(item: $selectedLog) { log in
                DailyLogDetailView(log: log)
            }
        }
    }

    // MARK: - Category Filters

    private var categoryFiltersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CloveSpacing.small) {
                ForEach(SearchCategory.allCases) { category in
                    CategoryFilterChip(
                        category: category,
                        isActive: viewModel.categoryFilters.isActive(category),
                        onTap: { viewModel.toggleCategory(category) }
                    )
                }
            }
            .padding(.horizontal, CloveSpacing.medium)
            .padding(.vertical, CloveSpacing.small)
        }
        .background(CloveColors.background)
    }

    // MARK: - Result Count

    private var resultCountHeader: some View {
        HStack {
            Text(resultCountText)
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText)

            Spacer()
        }
        .padding(.horizontal, CloveSpacing.medium)
        .padding(.vertical, CloveSpacing.small)
        .background(CloveColors.background)
    }

    private var resultCountText: String {
        if viewModel.hasMoreResults {
            return "Showing \(viewModel.searchResults.count) of \(viewModel.totalResultCount) results"
        } else {
            return "\(viewModel.totalResultCount) \(viewModel.totalResultCount == 1 ? "result" : "results")"
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Searching...")
                .font(CloveFonts.body())
                .foregroundStyle(CloveColors.secondaryText)
                .padding(.top, CloveSpacing.medium)
            Spacer()
        }
    }

    private var initialEmptyState: some View {
        EmptySearchStateView(stateType: .initial)
    }

    private var noResultsState: some View {
        EmptySearchStateView(stateType: .noResults)
    }

    // MARK: - Results List

    private var resultsListSection: some View {
        ScrollView {
            LazyVStack(spacing: CloveSpacing.medium) {
                ForEach(viewModel.searchResults) { result in
                    SearchResultCard(result: result) {
                        selectedLog = result.log
                    }
                }

                // Load More button
                if viewModel.hasMoreResults {
                    loadMoreButton
                }
            }
            .padding(.horizontal, CloveSpacing.medium)
            .padding(.vertical, CloveSpacing.small)
        }
        .background(CloveColors.background)
    }

    private var loadMoreButton: some View {
        Button(action: {
            viewModel.loadMoreResults()
        }) {
            HStack {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 16, weight: .medium))

                Text("Load More")
                    .font(CloveFonts.body())
            }
            .foregroundStyle(CloveColors.accent)
            .padding(.vertical, CloveSpacing.medium)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .fill(CloveColors.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .stroke(CloveColors.accent, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SearchView()
}
