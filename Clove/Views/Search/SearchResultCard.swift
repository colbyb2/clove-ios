import SwiftUI

struct SearchResultCard: View {
    let result: SearchResult
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: result.matchedCategory.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(result.matchedCategory.color)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(result.matchedCategory.color.opacity(0.13))
                    )

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(result.matchedCategory.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(result.matchedCategory.color)

                        Spacer()

                        Text(result.log.date.formatted(.dateTime.month(.abbreviated).day().year()))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(CloveColors.secondaryText)
                    }

                    Text(highlightedSnippet)
                        .font(CloveFonts.body())
                        .foregroundStyle(CloveColors.primaryText)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        Text(result.log.date.formatted(.dateTime.weekday(.wide)))
                            .font(.system(size: 12))
                            .foregroundStyle(CloveColors.secondaryText)

                        healthIndicators

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(CloveColors.secondaryText.opacity(0.7))
                    }
                }
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

    private var healthIndicators: some View {
        HStack(spacing: 7) {
            if let mood = result.log.mood {
                indicator(icon: CloveSymbols.mood(for: Double(mood)), value: mood, color: moodColor(mood))
            }
            if let pain = result.log.painLevel {
                indicator(icon: "cross.fill", value: pain, color: painColor(pain))
            }
        }
    }

    private func indicator(icon: String, value: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text("\(value)")
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(color)
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
