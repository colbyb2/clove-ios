import SwiftUI

struct ActivityTracker: View {
    let date: Date

    @State private var activityEntries: [ActivityEntry] = []
    @State private var showAddActivitySheet: Bool = false

    private let repo = ActivityEntryRepo.shared

    var body: some View {
        VStack(spacing: CloveSpacing.small) {
            // Main Header Row
            HStack {
                HStack(spacing: CloveSpacing.small) {
                    Text("🏃")
                        .font(.system(size: 20))
                    Text("Activities")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                }

                Spacer()

                Button(action: {
                    showAddActivitySheet = true
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }) {
                    HStack {
                        Text(activityButtonText())
                            .foregroundStyle(activityEntries.isEmpty ? CloveColors.secondaryText : CloveColors.primaryText)
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
                .accessibilityLabel("Add activity entry")
                .accessibilityHint("Opens activity selection sheet")
            }

            // Today's Activity Entries
            if !activityEntries.isEmpty {
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    ForEach(activityEntries) { entry in
                        ActivityEntryRow(entry: entry) {
                            deleteActivityEntry(entry)
                        }
                    }

                    // Total duration summary
                    if totalDuration > 0 {
                        HStack {
                            Spacer()
                            Text("Total: \(formattedTotalDuration)")
                                .font(.system(.caption, design: .rounded).weight(.medium))
                                .foregroundStyle(CloveColors.secondaryText)
                                .padding(.top, CloveSpacing.xsmall)
                        }
                    }
                }
            }
        }
        .padding(.vertical, CloveSpacing.small)
        .onAppear {
            loadActivityEntries()
        }
        .onChange(of: date) { _, _ in
            loadActivityEntries()
        }
        .sheet(isPresented: $showAddActivitySheet) {
            AddActivitySheet(date: date) {
                loadActivityEntries()
            }
        }
    }

    private var totalDuration: Int {
        activityEntries.compactMap { $0.duration }.reduce(0, +)
    }

    private var formattedTotalDuration: String {
        if totalDuration < 60 {
            return "\(totalDuration) min"
        } else {
            let hours = totalDuration / 60
            let minutes = totalDuration % 60
            if minutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(minutes)m"
            }
        }
    }

    private func activityButtonText() -> String {
        if activityEntries.isEmpty {
            return "Tap to track"
        }
        return "\(activityEntries.count)"
    }

    private func loadActivityEntries() {
        activityEntries = repo.getEntriesForDate(date)
    }

    private func deleteActivityEntry(_ entry: ActivityEntry) {
        guard let id = entry.id else { return }

        if repo.delete(id: id) {
            loadActivityEntries()

            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
}

// MARK: - Activity Entry Row

private struct ActivityEntryRow: View {
    let entry: ActivityEntry
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

                    if let duration = entry.formattedDuration {
                        Text(duration)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(CloveColors.secondaryText)
                    }

                    if let intensity = entry.intensity {
                        Text(intensity.indicator)
                            .font(.system(size: 12))
                            .foregroundStyle(intensityColor(intensity))
                    }

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
        case .exercise: return CloveColors.blue
        case .wellness: return CloveColors.green
        case .social: return CloveColors.orange
        case .chores: return CloveColors.yellow
        case .rest: return Theme.shared.accent
        case .other: return CloveColors.secondaryText
        }
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
    VStack {
        ActivityTracker(date: Date())
        Spacer()
    }
    .padding()
    .background(CloveColors.background)
}
