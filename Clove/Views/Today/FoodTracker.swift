import SwiftUI

struct FoodTracker: View {
    let date: Date

    @State private var foodEntries: [FoodEntry] = []
    @State private var showAddFoodSheet: Bool = false

    private let repo = FoodEntryRepo.shared

    var body: some View {
        VStack(spacing: CloveSpacing.small) {
            // Main Header Row
            HStack {
                HStack(spacing: CloveSpacing.small) {
                    Text("🍽️")
                        .font(.system(size: 20))
                    Text("Meals")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                }

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

            // Today's Food Entries grouped by category
            if !foodEntries.isEmpty {
                VStack(alignment: .leading, spacing: CloveSpacing.medium) {
                    ForEach(MealCategory.allCases) { category in
                        let categoryEntries = foodEntries.filter { $0.category == category }
                        if !categoryEntries.isEmpty {
                            FoodCategorySection(
                                category: category,
                                entries: categoryEntries,
                                onDelete: deleteFoodEntry
                            )
                        }
                    }
                }
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

// MARK: - Food Category Section

private struct FoodCategorySection: View {
    let category: MealCategory
    let entries: [FoodEntry]
    let onDelete: (FoodEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
            // Category header
            HStack(spacing: 6) {
                Text(category.emoji)
                    .font(.system(size: 14))

                Text(category.displayName)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(CloveColors.secondaryText)
            }

            // Food items
            FlowLayout(spacing: 8) {
                ForEach(entries) { entry in
                    FoodEntryChip(entry: entry) {
                        onDelete(entry)
                    }
                }
            }
        }
    }
}

// MARK: - Food Entry Chip

private struct FoodEntryChip: View {
    let entry: FoodEntry
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 6) {
            if entry.isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.yellow)
            }

            Text(entry.name)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(1)

            Button(action: {
                onDelete()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(width: 16, height: 16)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(CloveColors.green)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: CloveColors.green.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var maxHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                // Move to next row
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxHeight = max(maxHeight, currentY + rowHeight)
        }

        return (CGSize(width: maxWidth, height: maxHeight), positions)
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
