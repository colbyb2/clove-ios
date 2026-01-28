import SwiftUI

struct ManageFoodsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var allEntries: [FoodEntry] = []
    @State private var showingAddFood = false
    @State private var selectedCategory: MealCategory?

    private let repo = FoodEntryRepo.shared

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: CloveSpacing.small) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(CloveColors.secondaryText)

                TextField("Search foods...", text: $searchText)
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
                    MealCategoryChip(
                        title: "All",
                        isSelected: selectedCategory == nil
                    ) {
                        selectedCategory = nil
                    }

                    ForEach(MealCategory.allCases) { category in
                        MealCategoryChip(
                            title: category.displayName,
                            emoji: category.emoji,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
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
                            FoodManageRow(entry: entry) {
                                toggleFavorite(entry)
                            } onDelete: {
                                deleteEntry(entry)
                            }
                        }
                    }

                    if !filteredNonFavorites.isEmpty {
                        Section(header: Text("All Foods")) {
                            ForEach(filteredNonFavorites) { entry in
                                FoodManageRow(entry: entry) {
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
                    Section(header: Text("All Foods")) {
                        ForEach(filteredNonFavorites) { entry in
                            FoodManageRow(entry: entry) {
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
                    Image(systemName: "fork.knife")
                        .font(.system(size: 48))
                        .foregroundStyle(CloveColors.secondaryText)

                    Text("No Foods Found")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(CloveColors.primaryText)

                    Text("Start tracking foods to see them here")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)
                    Spacer()
                }
            }
        }
        .background(CloveColors.background)
        .navigationTitle("Manage Foods")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadEntries()
        }
    }

    // MARK: - Computed Properties

    private var uniqueEntries: [FoodEntry] {
        // Get unique food entries by name (keeping the most recent one)
        var seen = Set<String>()
        var unique: [FoodEntry] = []

        for entry in allEntries.sorted(by: { $0.date > $1.date }) {
            let key = entry.name.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(entry)
            }
        }

        return unique.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private var filteredEntries: [FoodEntry] {
        var entries = uniqueEntries

        // Filter by category
        if let category = selectedCategory {
            entries = entries.filter { $0.category == category }
        }

        // Filter by search text
        if !searchText.isEmpty {
            entries = entries.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }

        return entries
    }

    private var filteredFavorites: [FoodEntry] {
        filteredEntries.filter { $0.isFavorite }
    }

    private var filteredNonFavorites: [FoodEntry] {
        filteredEntries.filter { !$0.isFavorite }
    }

    // MARK: - Helper Methods

    private func loadEntries() {
        allEntries = repo.getAllEntries()
    }

    private func toggleFavorite(_ entry: FoodEntry) {
        guard let id = entry.id else { return }
        if repo.toggleFavorite(id: id) {
            loadEntries()

            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }

    private func deleteEntry(_ entry: FoodEntry) {
        guard let id = entry.id else { return }
        if repo.delete(id: id) {
            loadEntries()

            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
}

// MARK: - Supporting Views

private struct MealCategoryChip: View {
    let title: String
    var emoji: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let emoji = emoji {
                    Text(emoji)
                        .font(.system(size: 12))
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

private struct FoodManageRow: View {
    let entry: FoodEntry
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: CloveSpacing.medium) {
            // Category indicator
            Text(entry.category.emoji)
                .font(.system(size: 20))

            // Name and category
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(CloveColors.primaryText)

                Text(entry.category.displayName)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(CloveColors.secondaryText)
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
}

#Preview {
    NavigationView {
        ManageFoodsView()
    }
}
