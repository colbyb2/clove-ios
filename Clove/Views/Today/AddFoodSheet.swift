import SwiftUI

struct AddFoodSheet: View {
    let date: Date
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategory: MealCategory = .snack
    @State private var showingAddCustomFood = false

    private let repo = FoodEntryRepo.shared

    @State private var favorites: [FoodEntry] = []
    @State private var recentFoods: [String] = []

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                searchBar

                // Category tabs
                categoryTabs

                ScrollView {
                    VStack(alignment: .leading, spacing: CloveSpacing.large) {
                        // Quick add from search
                        if !searchText.isEmpty {
                            quickAddSection
                        }

                        // Favorites section
                        if !filteredFavorites.isEmpty {
                            favoritesSection
                        }

                        // Recent foods section
                        if !filteredRecents.isEmpty {
                            recentsSection
                        }

                        // Default suggestions
                        suggestionsSection
                    }
                    .padding()
                }
            }
            .background(CloveColors.background)
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(CloveColors.secondaryText)
                }
            }
            .onAppear {
                loadData()
            }
            .sheet(isPresented: $showingAddCustomFood) {
                AddCustomFoodSheet(
                    initialName: searchText,
                    initialCategory: selectedCategory,
                    date: date
                ) {
                    loadData()
                    onSave()
                    dismiss()
                }
            }
        }
    }

    // MARK: - Subviews

    private var searchBar: some View {
        HStack(spacing: CloveSpacing.small) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(CloveColors.secondaryText)

            TextField("Search or add new food...", text: $searchText)
                .textFieldStyle(.plain)
                .submitLabel(.done)
                .onSubmit {
                    if !searchText.isEmpty {
                        addFood(name: searchText, category: selectedCategory)
                    }
                }

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
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CloveSpacing.small) {
                ForEach(MealCategory.allCases) { category in
                    CategoryTab(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, CloveSpacing.small)
    }

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            Button(action: {
                addFood(name: searchText, category: selectedCategory)
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.shared.accent)

                    Text("Add \"\(searchText)\"")
                        .foregroundStyle(CloveColors.primaryText)
                        .fontWeight(.medium)

                    Spacer()

                    Text(selectedCategory.displayName)
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(CloveColors.card)
                        .clipShape(Capsule())
                }
                .padding()
                .background(Theme.shared.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: CloveCorners.medium))
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: {
                showingAddCustomFood = true
            }) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(CloveColors.secondaryText)

                    Text("Add with more details...")
                        .foregroundStyle(CloveColors.secondaryText)
                        .font(CloveFonts.small())

                    Spacer()
                }
                .padding(.horizontal)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            SectionHeader(title: "Favorites", icon: "star.fill", color: .yellow)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100), spacing: CloveSpacing.small)
            ], spacing: CloveSpacing.small) {
                ForEach(filteredFavorites) { entry in
                    FoodChip(
                        name: entry.name,
                        category: entry.category,
                        isFavorite: true
                    ) {
                        addFood(name: entry.name, category: entry.category)
                    }
                }
            }
        }
    }

    private var recentsSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            SectionHeader(title: "Recent", icon: "clock.fill", color: CloveColors.blue)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100), spacing: CloveSpacing.small)
            ], spacing: CloveSpacing.small) {
                ForEach(filteredRecents, id: \.self) { name in
                    FoodChip(
                        name: name,
                        category: selectedCategory,
                        isFavorite: false
                    ) {
                        addFood(name: name, category: selectedCategory)
                    }
                }
            }
        }
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            SectionHeader(title: "Suggestions", icon: "lightbulb.fill", color: CloveColors.orange)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100), spacing: CloveSpacing.small)
            ], spacing: CloveSpacing.small) {
                ForEach(filteredSuggestions, id: \.self) { name in
                    FoodChip(
                        name: name,
                        category: selectedCategory,
                        isFavorite: false
                    ) {
                        addFood(name: name, category: selectedCategory)
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredFavorites: [FoodEntry] {
        let categoryFiltered = favorites.filter { $0.category == selectedCategory }
        if searchText.isEmpty {
            return categoryFiltered
        }
        return categoryFiltered.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }

    private var filteredRecents: [String] {
        if searchText.isEmpty {
            return Array(recentFoods.prefix(8))
        }
        return recentFoods.filter { $0.lowercased().contains(searchText.lowercased()) }
    }

    private var filteredSuggestions: [String] {
        let suggestions = defaultSuggestions(for: selectedCategory)
        if searchText.isEmpty {
            return suggestions
        }
        return suggestions.filter { $0.lowercased().contains(searchText.lowercased()) }
    }

    // MARK: - Helper Methods

    private func loadData() {
        favorites = repo.getFavorites()
        recentFoods = repo.getRecentFoodNames(limit: 20)
    }

    private func addFood(name: String, category: MealCategory) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        let entry = FoodEntry(
            name: trimmed,
            category: category,
            date: date
        )

        if repo.save(entry) != nil {
            onSave()
            dismiss()
        }
    }

    private func defaultSuggestions(for category: MealCategory) -> [String] {
        switch category {
        case .breakfast:
            return ["Oatmeal", "Eggs", "Toast", "Cereal", "Pancakes", "Yogurt", "Fruit", "Bagel"]
        case .lunch:
            return ["Sandwich", "Salad", "Soup", "Wrap", "Pizza", "Burger", "Sushi", "Bowl"]
        case .dinner:
            return ["Chicken", "Pasta", "Fish", "Rice", "Steak", "Stir Fry", "Tacos", "Curry"]
        case .snack:
            return ["Apple", "Nuts", "Chips", "Crackers", "Cheese", "Popcorn", "Granola Bar", "Cookies"]
        case .beverage:
            return ["Water", "Coffee", "Tea", "Juice", "Smoothie", "Soda", "Milk", "Lemonade"]
        }
    }
}

// MARK: - Supporting Views

private struct CategoryTab: View {
    let category: MealCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(category.emoji)
                    .font(.system(size: 14))
                Text(category.displayName)
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

private struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: CloveSpacing.small) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 14))

            Text(title)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(CloveColors.primaryText)
        }
    }
}

private struct FoodChip: View {
    let name: String
    let category: MealCategory
    let isFavorite: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.yellow)
                }

                Text(name)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(CloveColors.primaryText)
                    .lineLimit(1)
            }
            .padding(.horizontal, CloveSpacing.medium)
            .padding(.vertical, CloveSpacing.small)
            .background(CloveColors.card)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Add Custom Food Sheet

struct AddCustomFoodSheet: View {
    let initialName: String
    let initialCategory: MealCategory
    let date: Date
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var category: MealCategory = .snack
    @State private var notes: String = ""
    @State private var isFavorite: Bool = false

    private let repo = FoodEntryRepo.shared

    var body: some View {
        NavigationView {
            Form {
                Section("Food Details") {
                    TextField("Name", text: $name)

                    Picker("Category", selection: $category) {
                        ForEach(MealCategory.allCases) { cat in
                            HStack {
                                Text(cat.emoji)
                                Text(cat.displayName)
                            }
                            .tag(cat)
                        }
                    }
                }

                Section("Additional Info") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)

                    Toggle(isOn: $isFavorite) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text("Add to Favorites")
                        }
                    }
                }
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveFood()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                name = initialName
                category = initialCategory
            }
        }
    }

    private func saveFood() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let entry = FoodEntry(
            name: trimmedName,
            category: category,
            date: date,
            notes: notes.isEmpty ? nil : notes,
            isFavorite: isFavorite
        )

        if repo.save(entry) != nil {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()

            onSave()
            dismiss()
        }
    }
}

#Preview {
    AddFoodSheet(date: Date()) {
        print("Food saved!")
    }
}
