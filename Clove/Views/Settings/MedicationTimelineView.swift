import SwiftUI

struct MedicationTimelineView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var medicationHistory: [MedicationHistoryEntry] = []
    @State private var groupedHistory: [String: [MedicationHistoryEntry]] = [:]
    
    private let medicationRepo = MedicationRepository.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if medicationHistory.isEmpty {
                    TimelineEmptyStateView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: CloveSpacing.medium) {
                            ForEach(sortedDateKeys, id: \.self) { dateKey in
                                TimelineDaySection(
                                    dateKey: dateKey,
                                    entries: groupedHistory[dateKey] ?? []
                                )
                            }
                        }
                        .padding(.horizontal, CloveSpacing.large)
                        .padding(.vertical, CloveSpacing.medium)
                    }
                }
            }
            .navigationTitle("Medication Timeline")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Theme.shared.accent)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadMedicationHistory()
        }
    }
    
    private var sortedDateKeys: [String] {
        groupedHistory.keys.sorted { first, second in
            // Sort by date descending (most recent first)
            dateFromKey(first) > dateFromKey(second)
        }
    }
    
    private func loadMedicationHistory() {
        medicationHistory = medicationRepo.getMedicationHistory()
        groupHistory()
    }
    
    private func groupHistory() {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        groupedHistory = Dictionary(grouping: medicationHistory) { entry in
            formatter.string(from: entry.changeDate)
        }
    }
    
    private func dateFromKey(_ key: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.date(from: key) ?? Date.distantPast
    }
}

// MARK: - Subviews

struct TimelineDaySection: View {
    let dateKey: String
    let entries: [MedicationHistoryEntry]
    
    private var sortedEntries: [MedicationHistoryEntry] {
        entries.sorted { $0.changeDate > $1.changeDate }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            // Date header
            HStack {
                Text(dateKey)
                    .font(CloveFonts.sectionTitle())
                    .foregroundStyle(CloveColors.primaryText)
                
                Spacer()
                
                Text("\(entries.count) change\(entries.count == 1 ? "" : "s")")
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
            }
            
            // History entries for this day
            VStack(spacing: CloveSpacing.small) {
                ForEach(sortedEntries, id: \.id) { entry in
                    TimelineEntryView(entry: entry)
                }
            }
        }
    }
}

struct TimelineEntryView: View {
    let entry: MedicationHistoryEntry
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        HStack(spacing: CloveSpacing.medium) {
            // Icon based on change type
            Image(systemName: iconForChangeType(entry.changeType))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(colorForChangeType(entry.changeType))
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
                // Main change description
                Text(descriptionForEntry(entry))
                    .font(CloveFonts.body())
                    .foregroundStyle(CloveColors.primaryText)
                
                // Time and additional details
                HStack {
                    Text(timeFormatter.string(from: entry.changeDate))
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                    
                    if let notes = entry.notes, !notes.isEmpty {
                        Text("•")
                            .font(CloveFonts.small())
                            .foregroundStyle(CloveColors.secondaryText)
                        
                        Text(notes)
                            .font(CloveFonts.small())
                            .foregroundStyle(CloveColors.secondaryText)
                    }
                }
                
                // Show before/after for changes
                if let oldValue = entry.oldValue, let newValue = entry.newValue,
                   entry.changeType != "added" && entry.changeType != "removed" {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("From:")
                                .font(CloveFonts.small())
                                .foregroundStyle(CloveColors.secondaryText)
                            Text(oldValue)
                                .font(CloveFonts.small())
                                .foregroundStyle(CloveColors.error)
                        }
                        HStack {
                            Text("To:")
                                .font(CloveFonts.small())
                                .foregroundStyle(CloveColors.secondaryText)
                            Text(newValue)
                                .font(CloveFonts.small())
                                .foregroundStyle(CloveColors.success)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, CloveSpacing.small)
        .padding(.horizontal, CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
        )
    }
    
    private func iconForChangeType(_ changeType: String) -> String {
        switch changeType {
        case "added": return "plus.circle.fill"
        case "removed": return "minus.circle.fill"
        case "dosage_changed": return "number.circle.fill"
        case "name_changed": return "textformat.abc"
        case "instructions_changed": return "doc.text.fill"
        case "schedule_changed": return "clock.fill"
        default: return "pencil.circle.fill"
        }
    }
    
    private func colorForChangeType(_ changeType: String) -> Color {
        switch changeType {
        case "added": return CloveColors.success
        case "removed": return CloveColors.error
        case "dosage_changed": return Theme.shared.accent
        case "name_changed": return CloveColors.primary
        case "instructions_changed": return .blue
        case "schedule_changed": return .orange
        default: return CloveColors.secondaryText
        }
    }
    
    private func descriptionForEntry(_ entry: MedicationHistoryEntry) -> String {
        switch entry.changeType {
        case "added":
            return "Added \(entry.medicationName)"
        case "removed":
            return "Removed \(entry.medicationName)"
        case "dosage_changed":
            return "Changed \(entry.medicationName) dosage"
        case "name_changed":
            return "Renamed medication to \(entry.medicationName)"
        case "instructions_changed":
            return "Updated \(entry.medicationName) instructions"
        case "schedule_changed":
            return "Changed \(entry.medicationName) schedule"
        default:
            return "Modified \(entry.medicationName)"
        }
    }
}

struct TimelineEmptyStateView: View {
    var body: some View {
        VStack(spacing: CloveSpacing.large) {
            Spacer()
            
            VStack(spacing: CloveSpacing.medium) {
                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: 60))
                    .foregroundStyle(CloveColors.secondaryText.opacity(0.5))
                
                Text("No Medication History")
                    .font(CloveFonts.title())
                    .foregroundStyle(CloveColors.primaryText)
                
                Text("Your medication changes will appear here as you add, edit, or remove medications from your tracking list.")
                    .font(CloveFonts.body())
                    .foregroundStyle(CloveColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, CloveSpacing.large)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    MedicationTimelineView()
}
