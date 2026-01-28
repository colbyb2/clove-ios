import SwiftUI

struct FoodTracker: View {
    let date: Date

    @State private var foodEntries: [FoodEntry] = []
    @State private var showAddFoodSheet: Bool = false
    @State private var isExpanded: Bool = true

    private let repo = FoodEntryRepo.shared

    var body: some View {
        VStack(spacing: CloveSpacing.small) {
            // Main Header Row
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }) {
                    HStack(spacing: CloveSpacing.small) {
                        Text("🍽️")
                            .font(.system(size: 20))
                        Text("Meals")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(CloveColors.primaryText)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(CloveColors.secondaryText)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                Button(action: {
                    showAddFoodSheet = true
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }) {
                    HStack {
                        Text(foodButtonText())
                            .foregroundStyle(foodEntries.isEmpty ? CloveColors.secondaryText : CloveColors.primaryText)
                            .font(.system(.body, design: .rounded).weight(.medium))

                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Theme.shared.accent)
                            .font(.system(size: 16))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(CloveColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
                    .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
                }
                .accessibilityLabel("Add food entry")
                .accessibilityHint("Opens food selection sheet")
            }

            // Today's Food Entries
            if !foodEntries.isEmpty && isExpanded {
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    ForEach(foodEntries) { entry in
                        FoodEntryRow(entry: entry) {
                            deleteFoodEntry(entry)
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
        .padding(.vertical, CloveSpacing.small)
        .onAppear {
            loadFoodEntries()
        }
        .onChange(of: date) { _, _ in
            loadFoodEntries()
        }
        .sheet(isPresented: $showAddFoodSheet) {
            AddFoodSheet(date: date) {
                loadFoodEntries()
            }
        }
    }

    private func foodButtonText() -> String {
        if foodEntries.isEmpty {
            return "Tap to track"
        }
        return "\(foodEntries.count)"
    }

    private func loadFoodEntries() {
        foodEntries = repo.getEntriesForDate(date)
    }

    private func deleteFoodEntry(_ entry: FoodEntry) {
        guard let id = entry.id else { return }

        if repo.delete(id: id) {
            loadFoodEntries()

            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
}

// MARK: - Food Entry Row

private struct FoodEntryRow: View {
    let entry: FoodEntry
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Category indicator
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: entry.category.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(categoryColor)
            }

            // Details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.name)
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(CloveColors.primaryText)

                    if entry.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.yellow)
                    }
                }

                HStack(spacing: 8) {
                    Text(entry.category.displayName)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(categoryColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(categoryColor.opacity(0.1))
                        )

                    Text(entry.formattedTime)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)
                }

                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(.caption))
                        .foregroundStyle(CloveColors.secondaryText)
                        .italic()
                        .lineLimit(1)
                }
            }

            Spacer()

            // Delete Button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(CloveColors.card.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
    }

    private var categoryColor: Color {
        switch entry.category {
        case .breakfast: return CloveColors.orange
        case .lunch: return CloveColors.yellow
        case .dinner: return Theme.shared.accent
        case .snack: return CloveColors.green
        case .beverage: return CloveColors.blue
        }
    }
}

#Preview {
    VStack {
        FoodTracker(date: Date())
        Spacer()
    }
    .padding()
    .background(CloveColors.background)
}
