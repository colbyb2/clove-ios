import SwiftUI

struct CategoryPickerView: View {
    let categories: [TrackingCategory]
    @Binding var selectedCategory: TrackingCategory
    @State private var isChoosingMetric = false

    private var metricCategories: [TrackingCategory] {
        categories.filter { $0 != .allData }
    }

    var body: some View {
        HStack(spacing: 4) {
            lensButton(
                title: "Overview",
                icon: "calendar",
                isSelected: selectedCategory == .allData
            ) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    selectedCategory = .allData
                }
            }

            lensButton(
                title: selectedCategory == .allData ? "Choose metric" : selectedCategory.displayName,
                icon: selectedCategory == .allData ? "chart.xyaxis.line" : selectedCategory.icon,
                isSelected: selectedCategory != .allData,
                showsChevron: true
            ) {
                isChoosingMetric = true
            }
        }
        .padding(4)
        .background(Capsule().fill(CloveColors.card))
        .overlay(Capsule().stroke(CloveColors.secondaryText.opacity(0.12), lineWidth: 1))
        .sheet(isPresented: $isChoosingMetric) {
            MetricPickerSheet(
                categories: metricCategories,
                selectedCategory: $selectedCategory,
                isPresented: $isChoosingMetric
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func lensButton(
        title: String,
        icon: String,
        isSelected: Bool,
        showsChevron: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if showsChevron {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .foregroundStyle(isSelected ? Theme.shared.accent : CloveColors.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, CloveSpacing.small)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(isSelected ? Theme.shared.accent.opacity(0.13) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MetricPickerSheet: View {
    let categories: [TrackingCategory]
    @Binding var selectedCategory: TrackingCategory
    @Binding var isPresented: Bool

    private var wellbeing: [TrackingCategory] {
        categories.filter { [.mood, .pain, .energy].contains($0) }
    }

    private var dailyTrackers: [TrackingCategory] {
        categories.filter {
            switch $0 {
            case .hydration, .meals, .activities, .medications, .bowelMovements: true
            default: false
            }
        }
    }

    private var symptoms: [TrackingCategory] {
        categories.filter {
            if case .symptom = $0 { return true }
            return false
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CloveSpacing.large) {
                    metricSection("Wellbeing", categories: wellbeing)
                    metricSection("Daily trackers", categories: dailyTrackers)
                    metricSection("Symptoms", categories: symptoms)
                }
                .padding(CloveSpacing.medium)
            }
            .background(CloveColors.background)
            .navigationTitle("Choose a metric")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.shared.accent)
                }
            }
        }
    }

    @ViewBuilder
    private func metricSection(_ title: String, categories: [TrackingCategory]) -> some View {
        if !categories.isEmpty {
            VStack(alignment: .leading, spacing: CloveSpacing.small) {
                Text(title)
                    .font(CloveFonts.small())
                    .fontWeight(.semibold)
                    .foregroundStyle(CloveColors.secondaryText)
                    .padding(.horizontal, 4)

                VStack(spacing: 0) {
                    ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                        Button {
                            selectedCategory = category
                            isPresented = false
                        } label: {
                            HStack(spacing: CloveSpacing.medium) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Theme.shared.accent)
                                    .frame(width: 34, height: 34)
                                    .background(Circle().fill(Theme.shared.accent.opacity(0.1)))

                                Text(category.displayName)
                                    .font(CloveFonts.body())
                                    .foregroundStyle(CloveColors.primaryText)

                                Spacer()

                                if selectedCategory == category {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.shared.accent)
                                }
                            }
                            .padding(.horizontal, CloveSpacing.medium)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)

                        if index < categories.count - 1 {
                            Divider().padding(.leading, 64)
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: CloveCorners.medium).fill(CloveColors.card))
            }
        }
    }
}

#Preview {
    CategoryPickerView(
        categories: [.allData, .mood, .pain, .energy, .hydration, .symptom(id: 1, name: "Headache")],
        selectedCategory: .constant(.mood)
    )
    .padding()
    .background(CloveColors.background)
}
