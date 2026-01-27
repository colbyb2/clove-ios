import SwiftUI

struct AddActivitySheet: View {
    let date: Date
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategory: ActivityCategory = .exercise
    @State private var showingAddCustomActivity = false

    private let repo = ActivityEntryRepo.shared

    @State private var favorites: [ActivityEntry] = []
    @State private var recentActivities: [String] = []

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

                        // Recent activities section
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
            .navigationTitle("Add Activity")
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
            .sheet(isPresented: $showingAddCustomActivity) {
                AddCustomActivitySheet(
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

            TextField("Search or add new activity...", text: $searchText)
                .textFieldStyle(.plain)
                .submitLabel(.done)
                .onSubmit {
                    if !searchText.isEmpty {
                        showingAddCustomActivity = true
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
                ForEach(ActivityCategory.allCases) { category in
                    ActivityCategoryTab(
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
                showingAddCustomActivity = true
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
        }
    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            ActivitySectionHeader(title: "Favorites", icon: "star.fill", color: .yellow)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 120), spacing: CloveSpacing.small)
            ], spacing: CloveSpacing.small) {
                ForEach(filteredFavorites) { entry in
                    ActivityChip(
                        name: entry.name,
                        category: entry.category,
                        duration: entry.duration,
                        intensity: entry.intensity,
                        isFavorite: true
                    ) {
                        addActivity(
                            name: entry.name,
                            category: entry.category,
                            duration: entry.duration,
                            intensity: entry.intensity
                        )
                    }
                }
            }
        }
    }

    private var recentsSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            ActivitySectionHeader(title: "Recent", icon: "clock.fill", color: CloveColors.blue)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 120), spacing: CloveSpacing.small)
            ], spacing: CloveSpacing.small) {
                ForEach(filteredRecents, id: \.self) { name in
                    ActivityChip(
                        name: name,
                        category: selectedCategory,
                        duration: nil,
                        intensity: nil,
                        isFavorite: false
                    ) {
                        addActivity(name: name, category: selectedCategory, duration: nil, intensity: nil)
                    }
                }
            }
        }
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            ActivitySectionHeader(title: "Suggestions", icon: "lightbulb.fill", color: CloveColors.orange)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 120), spacing: CloveSpacing.small)
            ], spacing: CloveSpacing.small) {
                ForEach(filteredSuggestions, id: \.self) { name in
                    ActivityChip(
                        name: name,
                        category: selectedCategory,
                        duration: nil,
                        intensity: nil,
                        isFavorite: false
                    ) {
                        addActivity(name: name, category: selectedCategory, duration: nil, intensity: nil)
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredFavorites: [ActivityEntry] {
        let categoryFiltered = favorites.filter { $0.category == selectedCategory }
        if searchText.isEmpty {
            return categoryFiltered
        }
        return categoryFiltered.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }

    private var filteredRecents: [String] {
        if searchText.isEmpty {
            return Array(recentActivities.prefix(8))
        }
        return recentActivities.filter { $0.lowercased().contains(searchText.lowercased()) }
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
        recentActivities = repo.getRecentActivityNames(limit: 20)
    }

    private func addActivity(name: String, category: ActivityCategory, duration: Int?, intensity: ActivityIntensity?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        let entry = ActivityEntry(
            name: trimmed,
            category: category,
            date: date,
            duration: duration,
            intensity: intensity
        )

        if repo.save(entry) != nil {
            onSave()
            dismiss()
        }
    }

    private func defaultSuggestions(for category: ActivityCategory) -> [String] {
        switch category {
        case .exercise:
            return ["Walking", "Running", "Gym", "Swimming", "Cycling", "Yoga", "Hiking", "Dancing"]
        case .wellness:
            return ["Meditation", "Stretching", "Deep Breathing", "Massage", "Spa", "Therapy", "Journaling", "Bath"]
        case .social:
            return ["Friends", "Family", "Date", "Party", "Phone Call", "Video Chat", "Dinner Out", "Game Night"]
        case .chores:
            return ["Cleaning", "Laundry", "Cooking", "Groceries", "Organizing", "Dishes", "Yard Work", "Errands"]
        case .rest:
            return ["Nap", "Reading", "TV", "Movies", "Gaming", "Relaxing", "Music", "Podcast"]
        case .other:
            return ["Work", "Study", "Hobbies", "Creative", "Travel", "Volunteering", "Self Care", "Planning"]
        }
    }
}

// MARK: - Supporting Views

private struct ActivityCategoryTab: View {
    let category: ActivityCategory
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

private struct ActivitySectionHeader: View {
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

private struct ActivityChip: View {
    let name: String
    let category: ActivityCategory
    let duration: Int?
    let intensity: ActivityIntensity?
    let isFavorite: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
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

                if duration != nil || intensity != nil {
                    HStack(spacing: 6) {
                        if let duration = duration {
                            Text("\(duration) min")
                                .font(.system(size: 11))
                                .foregroundStyle(CloveColors.secondaryText)
                        }

                        if let intensity = intensity {
                            Text(intensity.indicator)
                                .font(.system(size: 10))
                                .foregroundStyle(intensityColor(intensity))
                        }
                    }
                }
            }
            .padding(.horizontal, CloveSpacing.medium)
            .padding(.vertical, CloveSpacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CloveColors.card)
            .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func intensityColor(_ intensity: ActivityIntensity) -> Color {
        switch intensity {
        case .low: return CloveColors.green
        case .medium: return CloveColors.orange
        case .high: return CloveColors.red
        }
    }
}

// MARK: - Add Custom Activity Sheet

struct AddCustomActivitySheet: View {
    let initialName: String
    let initialCategory: ActivityCategory
    let date: Date
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var category: ActivityCategory = .exercise
    @State private var duration: Int?
    @State private var intensity: ActivityIntensity?
    @State private var notes: String = ""
    @State private var isFavorite: Bool = false

    @State private var durationText: String = ""

    private let repo = ActivityEntryRepo.shared

    var body: some View {
        NavigationView {
            Form {
                Section("Activity Details") {
                    TextField("Name", text: $name)

                    Picker("Category", selection: $category) {
                        ForEach(ActivityCategory.allCases) { cat in
                            HStack {
                                Text(cat.emoji)
                                Text(cat.displayName)
                            }
                            .tag(cat)
                        }
                    }
                }

                Section("Duration & Intensity") {
                    HStack {
                        Text("Duration")
                        Spacer()
                        TextField("minutes", text: $durationText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .onChange(of: durationText) { _, newValue in
                                duration = Int(newValue)
                            }
                        Text("min")
                            .foregroundStyle(CloveColors.secondaryText)
                    }

                    Picker("Intensity", selection: $intensity) {
                        Text("None").tag(nil as ActivityIntensity?)
                        ForEach(ActivityIntensity.allCases) { level in
                            HStack {
                                Text(level.indicator)
                                Text(level.displayName)
                            }
                            .tag(level as ActivityIntensity?)
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
            .navigationTitle("Add Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveActivity()
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

    private func saveActivity() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let entry = ActivityEntry(
            name: trimmedName,
            category: category,
            date: date,
            duration: duration,
            intensity: intensity,
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
    AddActivitySheet(date: Date()) {
        print("Activity saved!")
    }
}
