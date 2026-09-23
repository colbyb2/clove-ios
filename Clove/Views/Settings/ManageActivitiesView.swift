import SwiftUI

struct ManageActivitiesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var allEntries: [ActivityEntry] = []
    @State private var showingCategories = false
    @State private var categories: [ActivityCategoryDefinition] = ActivityCategoryDefinition.presets
    @State private var selectedCategoryID: String?

    private let repo = ActivityEntryRepo.shared

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: CloveSpacing.small) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(CloveColors.secondaryText)

                TextField("Search activities...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(CloveColors.secondaryText)
                    }
                }
            }
            .padding(CloveSpacing.medium)
            .background(CloveColors.card)
            .clipShape(RoundedRectangle(cornerRadius: CloveCorners.medium))
            .padding()

            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CloveSpacing.small) {
                    ActivityCategoryFilterChip(
                        title: "All",
                        isSelected: selectedCategoryID == nil
                    ) {
                        selectedCategoryID = nil
                    }

                    ForEach(categories) { category in
                        ActivityCategoryFilterChip(
                            title: category.name,
                            icon: category.symbol,
                            isSelected: selectedCategoryID == category.id
                        ) {
                            selectedCategoryID = category.id
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, CloveSpacing.small)

            // Favorites section
            if !filteredFavorites.isEmpty {
                List {
                    Section(header: Text("Favorites")) {
                        ForEach(filteredFavorites) { entry in
                            ActivityManageRow(entry: entry) {
                                toggleFavorite(entry)
                            } onDelete: {
                                deleteEntry(entry)
                            }
                        }
                    }

                    if !filteredNonFavorites.isEmpty {
                        Section(header: Text("All Activities")) {
                            ForEach(filteredNonFavorites) { entry in
                                ActivityManageRow(entry: entry) {
                                    toggleFavorite(entry)
                                } onDelete: {
                                    deleteEntry(entry)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            } else if !filteredNonFavorites.isEmpty {
                List {
                    Section(header: Text("All Activities")) {
                        ForEach(filteredNonFavorites) { entry in
                            ActivityManageRow(entry: entry) {
                                toggleFavorite(entry)
                            } onDelete: {
                                deleteEntry(entry)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                VStack(spacing: CloveSpacing.medium) {
                    Spacer()
                    Image(systemName: "figure.run")
                        .font(.system(size: 48))
                        .foregroundStyle(CloveColors.secondaryText)

                    Text("No Activities Found")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(CloveColors.primaryText)

                    Text("Start tracking activities to see them here")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)
                    Spacer()
                }
            }
        }
        .background(CloveColors.background)
        .navigationTitle("Manage Activities")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Categories") { showingCategories = true }
            }
        }
        .onAppear {
            loadEntries()
        }
        .sheet(isPresented: $showingCategories) {
            ManageActivityCategoriesSheet {
                categories = ActivityCategoryRepo.shared.getAll()
                if let selectedCategoryID,
                   !categories.contains(where: { $0.id == selectedCategoryID }) {
                    self.selectedCategoryID = nil
                }
                loadEntries()
            }
        }
    }

    // MARK: - Computed Properties

    private var uniqueEntries: [ActivityEntry] {
        // Get unique activity entries by name (keeping the most recent one)
        var seen = Set<String>()
        var unique: [ActivityEntry] = []

        for entry in allEntries.sorted(by: { $0.date > $1.date }) {
            let key = entry.name.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(entry)
            }
        }

        return unique.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private var filteredEntries: [ActivityEntry] {
        var entries = uniqueEntries

        // Filter by category
        if let selectedCategoryID {
            entries = entries.filter { ($0.categoryID ?? $0.category.rawValue) == selectedCategoryID }
        }

        // Filter by search text
        if !searchText.isEmpty {
            entries = entries.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }

        return entries
    }

    private var filteredFavorites: [ActivityEntry] {
        filteredEntries.filter { $0.isFavorite }
    }

    private var filteredNonFavorites: [ActivityEntry] {
        filteredEntries.filter { !$0.isFavorite }
    }

    // MARK: - Helper Methods

    private func loadEntries() {
        categories = ActivityCategoryRepo.shared.getAll()
        allEntries = repo.getAllEntries()
    }

    private func toggleFavorite(_ entry: ActivityEntry) {
        guard let id = entry.id else { return }
        if repo.toggleFavorite(id: id) {
            loadEntries()

            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }

    private func deleteEntry(_ entry: ActivityEntry) {
        guard let id = entry.id else { return }
        if repo.delete(id: id) {
            loadEntries()
            ToastManager.shared.showToast(
                message: "Activity deleted",
                color: CloveColors.secondaryText,
                icon: Image(systemName: "trash"),
                duration: 8,
                actionTitle: "Undo"
            ) {
                if repo.save(entry) != nil { loadEntries() }
            }
        }
    }
}

// MARK: - Supporting Views

private struct ActivityCategoryFilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
            }
            .padding(.horizontal, CloveSpacing.medium)
            .padding(.vertical, CloveSpacing.small)
            .background(isSelected ? Theme.shared.accent : CloveColors.card)
            .foregroundStyle(isSelected ? .white : CloveColors.primaryText)
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct ActivityManageRow: View {
    let entry: ActivityEntry
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void

    var body: some View {
        let category = entry.categoryDefinition
        HStack(spacing: CloveSpacing.medium) {
            // Category indicator
            Image(systemName: category.symbol)
                .font(.system(size: 18))
                .foregroundStyle(categoryColor)
                .frame(width: 28, height: 28)
                .background(categoryColor.opacity(0.15))
                .clipShape(Circle())

            // Name and details
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(CloveColors.primaryText)

                HStack(spacing: 6) {
                    Text(category.name)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)

                    if let duration = entry.duration {
                        Text("\(duration) min")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(CloveColors.secondaryText)
                    }

                    if let intensity = entry.intensity {
                        Text(intensity.indicator)
                            .font(.system(size: 10))
                            .foregroundStyle(intensityColor(intensity))
                    }
                }
            }

            Spacer()

            // Favorite button
            Button(action: onToggleFavorite) {
                Image(systemName: entry.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 18))
                    .foregroundStyle(entry.isFavorite ? .yellow : CloveColors.secondaryText)
            }
            .buttonStyle(PlainButtonStyle())

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
    }

    private var categoryColor: Color {
        entry.categoryDefinition.color
    }

    private func intensityColor(_ intensity: ActivityIntensity) -> Color {
        switch intensity {
        case .low: return CloveColors.green
        case .medium: return CloveColors.orange
        case .high: return CloveColors.red
        }
    }
}

#Preview {
    NavigationView {
        ManageActivitiesView()
    }
}
