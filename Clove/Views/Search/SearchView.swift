import SwiftUI

struct SearchView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel = SearchViewModel()
    @State private var selectedLog: DailyLog?
    @State private var userSettings: UserSettings?
    @State private var suggestedQueries: [String] = []
    @State private var showsFilters = false
    @FocusState private var searchIsFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            categoryControls

            Group {
                if viewModel.isSearching && viewModel.searchResults.isEmpty {
                    loadingState
                } else if viewModel.request.normalizedQuery.isEmpty {
                    discoveryContent
                } else if viewModel.searchResults.isEmpty && viewModel.hasSearched {
                    noResultsState
                } else {
                    resultsContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(CloveColors.background)
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedLog) { log in
            DailyLogDetailView(log: log)
        }
        .sheet(isPresented: $showsFilters) {
            SearchRefinementSheet(request: viewModel.request) { dateRange, start, end, sortOrder in
                viewModel.applyRefinements(
                    dateRange: dateRange,
                    customStartDate: start,
                    customEndDate: end,
                    sortOrder: sortOrder
                )
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            loadConfiguration()
            if dependencies.tutorialManager.startTutorial(Tutorials.SearchView) == .Failure {
                print("Tutorial [SearchView] Failed to Start")
            }
        }
    }

    private var searchHeader: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            HStack(spacing: CloveSpacing.small) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(searchIsFocused ? Theme.shared.accent : CloveColors.secondaryText)

                TextField("Symptom, meal, medication, note…", text: $viewModel.searchQuery)
                    .font(CloveFonts.body())
                    .foregroundStyle(CloveColors.primaryText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($searchIsFocused)
                    .onSubmit { viewModel.submitSearch() }

                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.clearSearch()
                        searchIsFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(CloveColors.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.large)
                    .fill(CloveColors.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: CloveCorners.large)
                            .stroke(
                                searchIsFocused ? Theme.shared.accent.opacity(0.75) : CloveColors.secondaryText.opacity(0.12),
                                lineWidth: searchIsFocused ? 1.5 : 1
                            )
                    )
            )
        }
        .padding(.horizontal, CloveSpacing.medium)
        .padding(.bottom, CloveSpacing.small)
    }

    private var categoryControls: some View {
        VStack(spacing: CloveSpacing.xsmall) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CloveSpacing.small) {
                    allCategoriesChip

                    ForEach(viewModel.availableCategories) { category in
                        compactCategoryChip(category)
                    }

                    filterButton
                }
                .padding(.horizontal, CloveSpacing.medium)
                .padding(.vertical, 2)
            }

            if viewModel.request.hasRefinements {
                activeRefinements
                    .padding(.horizontal, CloveSpacing.medium)
            }
        }
        .padding(.bottom, CloveSpacing.small)
    }

    private var allCategoriesChip: some View {
        Button { viewModel.selectAllCategories() } label: {
            Text("All")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(viewModel.selectedAllCategories ? Color.white : CloveColors.primaryText)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(
                    Capsule().fill(viewModel.selectedAllCategories ? Theme.shared.accent : CloveColors.card)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(viewModel.selectedAllCategories ? .isSelected : [])
    }

    private func compactCategoryChip(_ category: SearchCategory) -> some View {
        let isSelected = viewModel.request.categories.contains(category) && !viewModel.selectedAllCategories
        return Button { viewModel.toggleCategory(category) } label: {
            HStack(spacing: 5) {
                Image(systemName: category.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(category.rawValue)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(isSelected ? category.color : CloveColors.secondaryText)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                Capsule().fill(isSelected ? category.color.opacity(0.15) : CloveColors.card)
            )
            .overlay(
                Capsule().stroke(isSelected ? category.color.opacity(0.45) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var filterButton: some View {
        Button { showsFilters = true } label: {
            HStack(spacing: 5) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12, weight: .semibold))
                Text("Refine")
                    .font(.system(size: 13, weight: .medium))
                if viewModel.activeRefinementCount > 0 {
                    Text("\(viewModel.activeRefinementCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Theme.shared.accent))
                }
            }
            .foregroundStyle(viewModel.activeRefinementCount > 0 ? Theme.shared.accent : CloveColors.secondaryText)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Capsule().fill(CloveColors.card))
        }
        .buttonStyle(.plain)
    }

    private var activeRefinements: some View {
        HStack(spacing: CloveSpacing.xsmall) {
            if viewModel.request.dateRange != .allTime {
                refinementLabel(icon: "calendar", text: viewModel.request.dateRange.title)
            }
            if viewModel.request.sortOrder != .newestFirst {
                refinementLabel(icon: "arrow.up", text: viewModel.request.sortOrder.title)
            }
            Spacer()
            Button("Reset") { viewModel.resetRefinements() }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.shared.accent)
        }
    }

    private func refinementLabel(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(CloveColors.secondaryText)
    }

    private var discoveryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CloveSpacing.large) {
                if !viewModel.recentSearches.isEmpty {
                    recentSearchesSection
                }

                VStack(alignment: .leading, spacing: CloveSpacing.medium) {
                    sectionHeading("Try a search", subtitle: "Searches stay on this device")

                    VStack(spacing: CloveSpacing.small) {
                        ForEach(Array(suggestedQueries.prefix(4)), id: \.self) { suggestion in
                            suggestionRow(suggestion)
                        }
                    }
                }

                searchPromiseCard
            }
            .padding(.horizontal, CloveSpacing.medium)
            .padding(.top, CloveSpacing.small)
            .padding(.bottom, 110)
        }
    }

    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            HStack {
                Text("Recent")
                    .font(CloveFonts.sectionTitle())
                    .foregroundStyle(CloveColors.primaryText)
                Spacer()
                Button("Clear") { viewModel.clearRecentSearches() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.shared.accent)
            }

            VStack(spacing: 0) {
                ForEach(viewModel.recentSearches, id: \.self) { query in
                    HStack(spacing: 12) {
                        Button { viewModel.useSuggestion(query) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(CloveColors.secondaryText)
                                Text(query)
                                    .font(CloveFonts.body())
                                    .foregroundStyle(CloveColors.primaryText)
                                    .lineLimit(1)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)

                        Button { viewModel.removeRecentSearch(query) } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(CloveColors.secondaryText)
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(query) from recent searches")
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)

                    if query != viewModel.recentSearches.last {
                        Divider().padding(.leading, 46)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: CloveCorners.large).fill(CloveColors.card))
        }
    }

    private func suggestionRow(_ suggestion: String) -> some View {
        Button { viewModel.useSuggestion(suggestion) } label: {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.shared.accent)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Theme.shared.accent.opacity(0.12)))
                Text(suggestion)
                    .font(CloveFonts.body())
                    .foregroundStyle(CloveColors.primaryText)
                Spacer()
                Image(systemName: "arrow.up.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CloveColors.secondaryText)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background(RoundedRectangle(cornerRadius: CloveCorners.medium).fill(CloveColors.card))
        }
        .buttonStyle(.plain)
    }

    private var searchPromiseCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(CloveColors.green)
                .frame(width: 34, height: 34)
                .background(Circle().fill(CloveColors.green.opacity(0.12)))
            VStack(alignment: .leading, spacing: 3) {
                Text("Private by design")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CloveColors.primaryText)
                Text("Clove searches your local records directly. Nothing is uploaded or inferred.")
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(CloveSpacing.medium)
        .background(RoundedRectangle(cornerRadius: CloveCorners.large).fill(CloveColors.card))
    }

    private var resultsContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CloveSpacing.small) {
                HStack(alignment: .firstTextBaseline) {
                    Text(resultCountText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CloveColors.primaryText)
                    Spacer()
                    Text(viewModel.request.sortOrder.title)
                        .font(.system(size: 12))
                        .foregroundStyle(CloveColors.secondaryText)
                }
                .padding(.bottom, 2)

                ForEach(viewModel.searchResults) { result in
                    SearchResultCard(result: result) {
                        viewModel.submitSearch()
                        selectedLog = result.log
                    }
                }

                if viewModel.hasMoreResults {
                    Button { viewModel.loadMoreResults() } label: {
                        Label("Show more results", systemImage: "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.shared.accent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(RoundedRectangle(cornerRadius: CloveCorners.medium).fill(CloveColors.card))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, CloveSpacing.medium)
            .padding(.top, CloveSpacing.small)
            .padding(.bottom, 110)
        }
    }

    private var noResultsState: some View {
        VStack(spacing: CloveSpacing.medium) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(CloveColors.secondaryText)
            Text("No matching records")
                .font(CloveFonts.sectionTitle())
                .foregroundStyle(CloveColors.primaryText)
            Text("Try a shorter phrase, another category, or a wider date range.")
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 42)
            if viewModel.request.hasRefinements || !viewModel.selectedAllCategories {
                Button("Search everything") {
                    viewModel.selectAllCategories()
                    viewModel.resetRefinements()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.shared.accent)
                .padding(.top, 4)
            }
            Spacer()
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
            Text("Searching your records…")
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText)
            Spacer()
        }
    }

    private func sectionHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(CloveFonts.sectionTitle())
                .foregroundStyle(CloveColors.primaryText)
            Text(subtitle)
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText)
        }
    }

    private var resultCountText: String {
        viewModel.hasMoreResults
            ? "Showing \(viewModel.searchResults.count) of \(viewModel.totalResultCount) matches"
            : "\(viewModel.totalResultCount) \(viewModel.totalResultCount == 1 ? "match" : "matches")"
    }

    private func loadConfiguration() {
        userSettings = dependencies.settingsRepository.getSettings() ?? .default
        viewModel.setAvailableCategories(availableCategories)

        let symptomNames = dependencies.symptomsRepository.getTrackedSymptoms()
            .filter(\.isActive)
            .prefix(2)
            .map(\.name)
        let medications = dependencies.medicationRepository.getTrackedMedications().prefix(1).map(\.name)
        let activities = dependencies.activityEntryRepository.getRecentActivityNames(limit: 1)
        let foods = dependencies.foodEntryRepository.getRecentFoodNames(limit: 1)
        let candidates = Array(symptomNames) + medications + activities + foods
        suggestedQueries = candidates.reduce(into: []) { result, item in
            guard !result.contains(where: { $0.localizedCaseInsensitiveCompare(item) == .orderedSame }) else { return }
            result.append(item)
        }

        if suggestedQueries.isEmpty {
            suggestedQueries = ["Headache", "Walk", "Breakfast", "A note you remember"]
        }
    }

    private var availableCategories: [SearchCategory] {
        guard let settings = userSettings else { return SearchCategory.allCases }
        return SearchCategory.allCases.filter { category in
            switch category {
            case .notes: return settings.trackNotes
            case .symptoms: return settings.trackSymptoms
            case .meals: return settings.trackMeals
            case .activities: return settings.trackActivities
            case .medications: return settings.trackMeds
            case .bowelMovements: return settings.trackBowelMovements
            }
        }
    }
}

private struct SearchRefinementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var dateRange: SearchDateRange
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var sortOrder: SearchSortOrder
    let onApply: (SearchDateRange, Date?, Date?, SearchSortOrder) -> Void

    init(
        request: SearchRequest,
        onApply: @escaping (SearchDateRange, Date?, Date?, SearchSortOrder) -> Void
    ) {
        _dateRange = State(initialValue: request.dateRange)
        _startDate = State(initialValue: request.customStartDate ?? Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date())
        _endDate = State(initialValue: request.customEndDate ?? Date())
        _sortOrder = State(initialValue: request.sortOrder)
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CloveSpacing.large) {
                    selectionSection(title: "When", subtitle: "Limit results to a useful window") {
                        VStack(spacing: CloveSpacing.small) {
                            ForEach(SearchDateRange.allCases) { range in
                                selectionRow(
                                    title: range.title,
                                    icon: range == .custom ? "calendar.badge.clock" : "calendar",
                                    isSelected: dateRange == range
                                ) { dateRange = range }
                            }
                        }
                    }

                    if dateRange == .custom {
                        VStack(spacing: CloveSpacing.small) {
                            DatePicker("From", selection: $startDate, displayedComponents: .date)
                            Divider()
                            DatePicker("Through", selection: $endDate, in: startDate..., displayedComponents: .date)
                        }
                        .font(CloveFonts.body())
                        .padding(CloveSpacing.medium)
                        .background(RoundedRectangle(cornerRadius: CloveCorners.large).fill(CloveColors.card))
                    }

                    selectionSection(title: "Order", subtitle: "Choose how matches are arranged") {
                        VStack(spacing: CloveSpacing.small) {
                            ForEach(SearchSortOrder.allCases) { order in
                                selectionRow(
                                    title: order.title,
                                    icon: order == .newestFirst ? "arrow.down" : "arrow.up",
                                    isSelected: sortOrder == order
                                ) { sortOrder = order }
                            }
                        }
                    }
                }
                .padding(CloveSpacing.medium)
                .padding(.bottom, 30)
            }
            .background(CloveColors.background)
            .navigationTitle("Refine search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply(
                            dateRange,
                            dateRange == .custom ? startDate : nil,
                            dateRange == .custom ? endDate : nil,
                            sortOrder
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func selectionSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            Text(title)
                .font(CloveFonts.sectionTitle())
                .foregroundStyle(CloveColors.primaryText)
            Text(subtitle)
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText)
            content()
        }
    }

    private func selectionRow(
        title: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.shared.accent : CloveColors.secondaryText)
                    .frame(width: 24)
                Text(title)
                    .font(CloveFonts.body())
                    .foregroundStyle(CloveColors.primaryText)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Theme.shared.accent : CloveColors.secondaryText.opacity(0.45))
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .background(RoundedRectangle(cornerRadius: CloveCorners.medium).fill(CloveColors.card))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { SearchView() }
}
