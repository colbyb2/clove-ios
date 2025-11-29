import SwiftUI

struct SearchResultCard: View {
    let result: SearchResult
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: CloveSpacing.small) {
                // Header row: date, category badge, indicators
                HStack {
                    Text(result.log.date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)

                    Spacer()

                    categoryBadge

                    healthIndicators
                }

                // Matched text snippet with highlighting
                Text(highlightedSnippet)
                    .font(CloveFonts.body())
                    .foregroundStyle(CloveColors.primaryText)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(CloveSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .fill(CloveColors.card)
                    .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Subviews

    private var categoryBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: result.matchedCategory.icon)
                .font(.system(size: 10, weight: .medium))

            Text(result.matchedCategory.rawValue)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(result.matchedCategory.color.opacity(0.15))
        )
        .foregroundStyle(result.matchedCategory.color)
    }

    private var healthIndicators: some View {
        HStack(spacing: 4) {
            if let mood = result.log.mood {
                Circle()
                    .fill(moodColor(mood))
                    .frame(width: 8, height: 8)
            }
            if let pain = result.log.painLevel {
                Circle()
                    .fill(painColor(pain))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var highlightedSnippet: AttributedString {
        var attributedString = AttributedString(result.contextSnippet)

        // Find and highlight search term
        if let range = result.contextSnippet.range(of: result.matchedText, options: .caseInsensitive) {
            if let lowerBound = AttributedString.Index(range.lowerBound, within: attributedString),
               let upperBound = AttributedString.Index(range.upperBound, within: attributedString) {
                let attributedRange = lowerBound..<upperBound

                attributedString[attributedRange].backgroundColor = Color.yellow.opacity(0.3)
                attributedString[attributedRange].foregroundColor = CloveColors.primaryText
                attributedString[attributedRange].font = .system(.body, design: .rounded).weight(.semibold)
            }
        }

        return attributedString
    }

    // MARK: - Helper Methods

    private func moodColor(_ mood: Int) -> Color {
        switch mood {
        case 8...10:
            return CloveColors.green
        case 5...7:
            return CloveColors.yellow
        case 1...4:
            return CloveColors.red
        default:
            return CloveColors.secondaryText
        }
    }

    private func painColor(_ pain: Int) -> Color {
        switch pain {
        case 8...10:
            return CloveColors.red
        case 5...7:
            return CloveColors.orange
        case 1...4:
            return CloveColors.yellow
        default:
            return CloveColors.secondaryText
        }
    }
}

#Preview {
    let mockLog = DailyLog(
        date: Date(),
        mood: 8,
        painLevel: 3,
        notes: "Had a headache today but it wasn't too bad. Took some ibuprofen and rested."
    )

    let mockResult = SearchResult(
        log: mockLog,
        matchedCategory: .notes,
        matchedText: "headache",
        contextSnippet: "Had a headache today but it wasn't too bad. Took some ibuprofen...",
        matchRange: "headache".startIndex..<"headache".endIndex
    )

    return VStack(spacing: 16) {
        SearchResultCard(result: mockResult, onTap: {})
    }
    .padding()
    .background(CloveColors.background)
}
