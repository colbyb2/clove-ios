import SwiftUI

struct SearchView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel = SearchViewModel()
    @State private var selectedLog: DailyLog?
    @State private var userSettings: UserSettings?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Category filters section
                categoryFiltersSection

                // Results count (if applicable)
                if !viewModel.searchResults.isEmpty {
                    resultCountHeader
                        .transition(.opacity)
                }

                // Main content
                if viewModel.isSearching {
                    loadingState
                        .transition(.opacity)
                } else if viewModel.searchQuery.isEmpty {
                    initialEmptyState
                        .transition(.opacity)
                } else if viewModel.searchResults.isEmpty && viewModel.hasSearched {
                    noResultsState
                        .transition(.opacity)
                } else if !viewModel.searchResults.isEmpty {
                    resultsListSection
                        .transition(.opacity)
                } else {
                    // Temporary state while debouncing (query exists but search hasn't run yet)
                    Spacer()
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.isSearching)
            .animation(.easeInOut(duration: 0.25), value: viewModel.searchResults.count)
            .animation(.easeInOut(duration: 0.25), value: viewModel.searchQuery.isEmpty)
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
            .onAppear {
                loadUserSettings()
                // Trigger tutorial on first visit
                if dependencies.tutorialManager.startTutorial(Tutorials.SearchView) == .Failure {
                    print("Tutorial [SearchView] Failed to Start")
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func loadUserSettings() {
        userSettings = dependencies.settingsRepository.getSettings() ?? .default
    }

    private var availableCategories: [SearchCategory] {
        guard let settings = userSettings else {
            return SearchCategory.allCases
        }

        return SearchCategory.allCases.filter { category in
            switch category {
            case .notes:
                return settings.trackNotes
            case .symptoms:
                return settings.trackSymptoms
            case .meals:
                return settings.trackMeals
            case .activities:
                return settings.trackActivities
            case .medications:
                return settings.trackMeds
            case .bowelMovements:
                return settings.trackBowelMovements
            }
        }
    }

    // MARK: - Category Filters

    private var categoryFiltersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CloveSpacing.small) {
                ForEach(availableCategories) { category in
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
                    .transition(.opacity)
                }

                // Load More button
                if viewModel.hasMoreResults {
                    loadMoreButton
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, CloveSpacing.medium)
            .padding(.vertical, CloveSpacing.small)
        }
        .background(CloveColors.background)
    }

    private var loadMoreButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.loadMoreResults()
            }
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
