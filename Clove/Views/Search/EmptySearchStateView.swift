import SwiftUI

struct EmptySearchStateView: View {
    enum StateType {
        case initial
        case noResults
    }

    let stateType: StateType

    var body: some View {
        VStack(spacing: CloveSpacing.large) {
            Image(systemName: iconName)
                .font(.system(size: 60, weight: .light))
                .foregroundStyle(CloveColors.secondaryText.opacity(0.5))

            VStack(spacing: CloveSpacing.small) {
                Text(title)
                    .font(CloveFonts.sectionTitle())
                    .foregroundStyle(CloveColors.primaryText)

                Text(subtitle)
                    .font(CloveFonts.body())
                    .foregroundStyle(CloveColors.secondaryText)
                    .multilineTextAlignment(.center)
            }

            if stateType == .initial {
                tipsSection
            }
        }
        .padding(CloveSpacing.xlarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Computed Properties

    private var iconName: String {
        switch stateType {
        case .initial:
            return "magnifyingglass"
        case .noResults:
            return "doc.text.magnifyingglass"
        }
    }

    private var title: String {
        switch stateType {
        case .initial:
            return "Search Your Health Logs"
        case .noResults:
            return "No Results Found"
        }
    }

    private var subtitle: String {
        switch stateType {
        case .initial:
            return "Find past symptoms, meals, activities, and more"
        case .noResults:
            return "Try adjusting your search or filters"
        }
    }

    // MARK: - Subviews

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            tipRow(icon: "bandage", text: "Search by symptom names")
            tipRow(icon: "fork.knife", text: "Find specific meals or activities")
            tipRow(icon: "pills", text: "Look up medications")
            tipRow(icon: "note.text", text: "Review notes from any day")
        }
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
        )
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: CloveSpacing.small) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CloveColors.accent)
                .frame(width: 20)

            Text(text)
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText)
        }
    }
}

#Preview {
    VStack {
        EmptySearchStateView(stateType: .initial)
            .background(CloveColors.background)

        Divider()

        EmptySearchStateView(stateType: .noResults)
            .background(CloveColors.background)
    }
}
