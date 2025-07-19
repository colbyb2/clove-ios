import SwiftUI

struct MedicationTimelineView: View {
   @Environment(\.dismiss) private var dismiss
   @State private var medicationHistory: [MedicationHistoryEntry] = []
   @State private var groupedHistory: [String: [MedicationHistoryEntry]] = [:]
   
   // Search functionality
   @State private var searchText: String = ""
   @State private var isSearching: Bool = false
   @FocusState private var isSearchFocused: Bool
   
   // Animation states
   @State private var headerOpacity: Double = 0
   @State private var contentOpacity: Double = 0
   @State private var headerOffset: CGFloat = -20
   @State private var contentOffset: CGFloat = 30
   @State private var daySequenceVisible: [Bool] = []
   
   private let medicationRepo = MedicationRepository.shared
   
   // Computed properties for filtered data
   private var filteredMedicationHistory: [MedicationHistoryEntry] {
      if searchText.isEmpty {
         return medicationHistory
      } else {
         return medicationHistory.filter { entry in
            entry.medicationName.localizedCaseInsensitiveContains(searchText)
         }
      }
   }
   
   private var filteredGroupedHistory: [String: [MedicationHistoryEntry]] {
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      
      return Dictionary(grouping: filteredMedicationHistory) { entry in
         formatter.string(from: entry.changeDate)
      }
   }
   
   private var filteredSortedDateKeys: [String] {
      filteredGroupedHistory.keys.sorted { first, second in
         // Sort by date descending (most recent first)
         dateFromKey(first) > dateFromKey(second)
      }
   }
   
   var body: some View {
      NavigationView {
         ZStack {
            // Subtle gradient background
            LinearGradient(
               colors: [
                  Theme.shared.accent.opacity(0.02),
                  CloveColors.background,
                  Theme.shared.accent.opacity(0.01)
               ],
               startPoint: .topLeading,
               endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 10) {
               // Custom header
               ModernTimelineHeaderView(
                  searchText: $searchText,
                  isSearching: $isSearching,
                  isSearchFocused: $isSearchFocused
               )
               .opacity(headerOpacity)
               .offset(y: headerOffset)
               
               if filteredMedicationHistory.isEmpty {
                  if searchText.isEmpty {
                     TimelineEmptyStateView()
                        .opacity(contentOpacity)
                        .offset(y: contentOffset)
                  } else {
                     SearchEmptyStateView(searchText: searchText)
                        .opacity(contentOpacity)
                        .offset(y: contentOffset)
                  }
               } else {
                  ScrollView {
                     LazyVStack(spacing: CloveSpacing.large) {
                        ForEach(Array(filteredSortedDateKeys.enumerated()), id: \.element) { index, dateKey in
                           TimelineDaySection(
                              dateKey: dateKey,
                              entries: filteredGroupedHistory[dateKey] ?? []
                           )
                           .opacity(daySequenceVisible.indices.contains(index) ? (daySequenceVisible[index] ? 1.0 : 0) : 0)
                           .scaleEffect(daySequenceVisible.indices.contains(index) ? (daySequenceVisible[index] ? 1.0 : 0.95) : 0.95)
                           .animation(.spring(response: 0.5, dampingFraction: 0.8), value: daySequenceVisible.indices.contains(index) ? daySequenceVisible[index] : false)
                        }
                     }
                     .padding(.horizontal, CloveSpacing.large)
                     .padding(.vertical, CloveSpacing.medium)
                  }
                  .opacity(contentOpacity)
                  .offset(y: contentOffset)
               }
            }
         }
         .navigationBarHidden(true)
      }
      .onAppear {
         loadMedicationHistory()
         startEntranceAnimations()
      }
      .onChange(of: searchText) { _, _ in
         updateAnimationsForFilteredData()
      }
   }
   
   private func startEntranceAnimations() {
      withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
         headerOpacity = 1.0
         headerOffset = 0
      }
      
      withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
         contentOpacity = 1.0
         contentOffset = 0
      }
      
      // Animate day sections individually
      if !filteredMedicationHistory.isEmpty {
         DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            for i in 0..<daySequenceVisible.count {
               withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(i) * 0.1)) {
                  daySequenceVisible[i] = true
               }
            }
         }
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
      updateAnimationsForFilteredData()
   }
   
   private func updateAnimationsForFilteredData() {
      daySequenceVisible = Array(repeating: false, count: filteredSortedDateKeys.count)
      
      // Trigger animations for the filtered data
      if !filteredMedicationHistory.isEmpty {
         DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for i in 0..<daySequenceVisible.count {
               withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(i) * 0.05)) {
                  daySequenceVisible[i] = true
               }
            }
         }
      }
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

// MARK: - Modern Views

struct ModernTimelineHeaderView: View {
   @Binding var searchText: String
   @Binding var isSearching: Bool
   @FocusState.Binding var isSearchFocused: Bool
   
   var body: some View {
      VStack(spacing: CloveSpacing.medium) {
         // Main header
         HStack(spacing: CloveSpacing.medium) {
            ZStack {
               Circle()
                  .fill(Theme.shared.accent.opacity(0.1))
                  .frame(width: 50, height: 50)
               
               Image(systemName: "clock.arrow.circlepath")
                  .font(.system(size: 24, weight: .medium))
                  .foregroundStyle(Theme.shared.accent)
            }
            
            VStack(alignment: .leading, spacing: 4) {
               Text("Medication Timeline")
                  .font(.system(.title2, design: .rounded, weight: .bold))
                  .foregroundStyle(CloveColors.primaryText)
            }
            
            Spacer()
         }
         
         // Search bar
         HStack(spacing: CloveSpacing.medium) {
            HStack(spacing: CloveSpacing.small) {
               Image(systemName: "magnifyingglass")
                  .font(.system(size: 16, weight: .medium))
                  .foregroundStyle(isSearchFocused || !searchText.isEmpty ? Theme.shared.accent : CloveColors.secondaryText)
                  .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
               
               TextField("Search medications...", text: $searchText)
                  .autocorrectionDisabled()
                  .focused($isSearchFocused)
                  .font(.system(.body, design: .rounded))
                  .foregroundStyle(CloveColors.primaryText)
                  .onTapGesture {
                     isSearching = true
                  }
               
               if !searchText.isEmpty {
                  Button(action: {
                     searchText = ""
                     isSearchFocused = false
                     isSearching = false
                  }) {
                     Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(CloveColors.secondaryText)
                  }
                  .transition(.scale.combined(with: .opacity))
               }
            }
            .padding(.horizontal, CloveSpacing.medium)
            .padding(.vertical, CloveSpacing.small)
            .background(
               RoundedRectangle(cornerRadius: CloveCorners.medium)
                  .fill(CloveColors.background)
                  .overlay(
                     RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke(isSearchFocused ? Theme.shared.accent : Color.gray, lineWidth: 1)
                        .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
                  )
            )
            
            if isSearching || !searchText.isEmpty {
               Button(action: {
                  searchText = ""
                  isSearchFocused = false
                  isSearching = false
               }) {
                  Text("Cancel")
                     .font(.system(.body, design: .rounded, weight: .medium))
                     .foregroundStyle(Theme.shared.accent)
               }
               .transition(.asymmetric(
                  insertion: .move(edge: .trailing).combined(with: .opacity),
                  removal: .move(edge: .trailing).combined(with: .opacity)
               ))
            }
         }
         .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSearching)
         .animation(.spring(response: 0.4, dampingFraction: 0.8), value: searchText.isEmpty)
      }
      .padding(CloveSpacing.large)
      .background(
         RoundedRectangle(cornerRadius: CloveCorners.large)
            .fill(CloveColors.card)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
      )
      .padding(.horizontal, CloveSpacing.large)
      .padding(.top, CloveSpacing.medium)
   }
}

struct TimelineDaySection: View {
   let dateKey: String
   let entries: [MedicationHistoryEntry]
   @State private var entryAnimationsVisible: [Bool] = []
   
   private var sortedEntries: [MedicationHistoryEntry] {
      entries.sorted { $0.changeDate > $1.changeDate }
   }
   
   var body: some View {
      VStack(alignment: .leading, spacing: CloveSpacing.medium) {
         // Enhanced date header
         HStack {
            VStack(alignment: .leading, spacing: 4) {
               Text(dateKey)
                  .font(.system(.title3, design: .rounded, weight: .semibold))
                  .foregroundStyle(CloveColors.primaryText)
               
               Text("\(entries.count) change\(entries.count == 1 ? "" : "s")")
                  .font(.system(.subheadline, design: .rounded))
                  .foregroundStyle(CloveColors.secondaryText)
            }
            
            Spacer()
            
            // Day summary badge
            HStack(spacing: CloveSpacing.small) {
               Circle()
                  .fill(Theme.shared.accent)
                  .frame(width: 8, height: 8)
               
               Text("\(entries.count)")
                  .font(.system(.subheadline, design: .rounded, weight: .semibold))
                  .foregroundStyle(Theme.shared.accent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
               Capsule()
                  .fill(Theme.shared.accent.opacity(0.1))
            )
         }
         
         // Timeline entries
         VStack(spacing: CloveSpacing.medium) {
            ForEach(Array(sortedEntries.enumerated()), id: \.element.id) { index, entry in
               TimelineEntryView(entry: entry)
                  .opacity(entryAnimationsVisible.indices.contains(index) ? (entryAnimationsVisible[index] ? 1.0 : 0) : 0)
                  .offset(x: entryAnimationsVisible.indices.contains(index) ? (entryAnimationsVisible[index] ? 0 : 20) : 20)
                  .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.05), value: entryAnimationsVisible.indices.contains(index) ? entryAnimationsVisible[index] : false)
            }
         }
      }
      .padding(CloveSpacing.large)
      .background(
         RoundedRectangle(cornerRadius: CloveCorners.large)
            .fill(CloveColors.card)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
      )
      .onAppear {
         entryAnimationsVisible = Array(repeating: false, count: sortedEntries.count)
         
         DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            for i in 0..<entryAnimationsVisible.count {
               entryAnimationsVisible[i] = true
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
         // Enhanced icon with gradient background
         ZStack {
            Circle()
               .fill(colorForChangeType(entry.changeType).opacity(0.1))
               .frame(width: 40, height: 40)
            
            Image(systemName: iconForChangeType(entry.changeType))
               .font(.system(size: 16, weight: .medium))
               .foregroundStyle(colorForChangeType(entry.changeType))
         }
         
         VStack(alignment: .leading, spacing: CloveSpacing.small) {
            // Main change description
            Text(descriptionForEntry(entry))
               .font(.system(.body, design: .rounded, weight: .medium))
               .foregroundStyle(CloveColors.primaryText)
            
            // Time and additional details
            HStack(spacing: CloveSpacing.small) {
               HStack(spacing: 4) {
                  Image(systemName: "clock")
                     .font(.system(size: 12))
                     .foregroundStyle(CloveColors.secondaryText.opacity(0.7))
                  
                  Text(timeFormatter.string(from: entry.changeDate))
                     .font(.system(.subheadline, design: .rounded))
                     .foregroundStyle(CloveColors.secondaryText)
               }
               
               
            }
            
            // Enhanced before/after changes display
            if let oldValue = entry.oldValue, let newValue = entry.newValue,
               entry.changeType != "added" && entry.changeType != "removed" && entry.changeType != "instructions_changed" {
               VStack(spacing: CloveSpacing.small) {
                  HStack(spacing: CloveSpacing.small) {
                     Text("From:")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(CloveColors.secondaryText)
                     
                     Text(oldValue)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                           Capsule()
                              .fill(CloveColors.error.opacity(0.8))
                        )
                  }
                  
                  HStack(spacing: CloveSpacing.small) {
                     Text("To:")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(CloveColors.secondaryText)
                     
                     Text(newValue)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                           Capsule()
                              .fill(CloveColors.success.opacity(0.8))
                        )
                  }
               }
               .padding(.top, CloveSpacing.small)
            }
         }
         
         Spacer()
         
         // Change type badge
         Text(changeTypeBadgeText(entry.changeType))
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(colorForChangeType(entry.changeType))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
               Capsule()
                  .fill(colorForChangeType(entry.changeType).opacity(0.1))
                  .overlay(
                     Capsule()
                        .stroke(colorForChangeType(entry.changeType).opacity(0.3), lineWidth: 1)
                  )
            )
      }
      .padding(CloveSpacing.medium)
      .background(
         RoundedRectangle(cornerRadius: CloveCorners.medium)
            .fill(CloveColors.background)
            .overlay(
               RoundedRectangle(cornerRadius: CloveCorners.medium)
                  .stroke(colorForChangeType(entry.changeType).opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
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
   
   private func changeTypeBadgeText(_ changeType: String) -> String {
      switch changeType {
      case "added": return "Added"
      case "removed": return "Removed"
      case "dosage_changed": return "Dosage"
      case "name_changed": return "Renamed"
      case "instructions_changed": return "Instructions"
      case "schedule_changed": return "Schedule"
      default: return "Modified"
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
      VStack(spacing: CloveSpacing.xlarge) {
         Spacer()
         
         VStack(spacing: CloveSpacing.large) {
            // Enhanced empty state icon
            ZStack {
               Circle()
                  .fill(Theme.shared.accent.opacity(0.1))
                  .frame(width: 120, height: 120)
               
               Circle()
                  .fill(Theme.shared.accent.opacity(0.05))
                  .frame(width: 100, height: 100)
               
               Image(systemName: "clock.arrow.circlepath")
                  .font(.system(size: 48, weight: .light))
                  .foregroundStyle(Theme.shared.accent.opacity(0.6))
            }
            
            VStack(spacing: CloveSpacing.medium) {
               Text("No Timeline History")
                  .font(.system(.title2, design: .rounded, weight: .bold))
                  .foregroundStyle(CloveColors.primaryText)
               
               VStack(spacing: CloveSpacing.small) {
                  Text("Your medication changes will appear here")
                     .font(.system(.body, design: .rounded))
                     .foregroundStyle(CloveColors.secondaryText)
                  
                  Text("Add, edit, or remove medications to see your timeline")
                     .font(.system(.subheadline, design: .rounded))
                     .foregroundStyle(CloveColors.secondaryText.opacity(0.8))
               }
               .multilineTextAlignment(.center)
            }
            
            // Helpful tips
            VStack(spacing: CloveSpacing.medium) {
               Text("Timeline tracks:")
                  .font(.system(.subheadline, design: .rounded, weight: .semibold))
                  .foregroundStyle(CloveColors.primaryText)
               
               VStack(spacing: CloveSpacing.small) {
                  TimelineFeatureRow(icon: "plus.circle", text: "Medication additions", color: CloveColors.success)
                  TimelineFeatureRow(icon: "pencil.circle", text: "Dosage changes", color: Theme.shared.accent)
                  TimelineFeatureRow(icon: "doc.text", text: "Instruction updates", color: .blue)
                  TimelineFeatureRow(icon: "minus.circle", text: "Medication removals", color: CloveColors.error)
               }
            }
         }
         .padding(.horizontal, CloveSpacing.xlarge)
         
         Spacer()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(CloveSpacing.large)
      .background(
         RoundedRectangle(cornerRadius: CloveCorners.large)
            .fill(CloveColors.card)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
      )
      .padding(.horizontal, CloveSpacing.large)
   }
}

struct SearchEmptyStateView: View {
   let searchText: String
   
   var body: some View {
      VStack(spacing: CloveSpacing.xlarge) {
         Spacer()
         
         VStack(spacing: CloveSpacing.large) {
            // Search empty state icon
            ZStack {
               Circle()
                  .fill(CloveColors.secondaryText.opacity(0.1))
                  .frame(width: 120, height: 120)
               
               Circle()
                  .fill(CloveColors.secondaryText.opacity(0.05))
                  .frame(width: 100, height: 100)
               
               Image(systemName: "magnifyingglass")
                  .font(.system(size: 48, weight: .light))
                  .foregroundStyle(CloveColors.secondaryText.opacity(0.6))
            }
            
            VStack(spacing: CloveSpacing.medium) {
               Text("No Results Found")
                  .font(.system(.title2, design: .rounded, weight: .bold))
                  .foregroundStyle(CloveColors.primaryText)
               
               VStack(spacing: CloveSpacing.small) {
                  Text("No medications found for \"\(searchText)\"")
                     .font(.system(.body, design: .rounded))
                     .foregroundStyle(CloveColors.secondaryText)
                  
                  Text("Try a different search term or check your spelling")
                     .font(.system(.subheadline, design: .rounded))
                     .foregroundStyle(CloveColors.secondaryText.opacity(0.8))
               }
               .multilineTextAlignment(.center)
            }
            
            // Search tips
            VStack(spacing: CloveSpacing.medium) {
               Text("Search tips:")
                  .font(.system(.subheadline, design: .rounded, weight: .semibold))
                  .foregroundStyle(CloveColors.primaryText)
               
               VStack(spacing: CloveSpacing.small) {
                  SearchTipRow(icon: "magnifyingglass", text: "Search by medication name")
                  SearchTipRow(icon: "textformat.abc", text: "Try partial names or brand names")
                  SearchTipRow(icon: "xmark.circle", text: "Clear search to see all history")
               }
            }
         }
         .padding(.horizontal, CloveSpacing.xlarge)
         
         Spacer()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(CloveSpacing.large)
      .background(
         RoundedRectangle(cornerRadius: CloveCorners.large)
            .fill(CloveColors.card)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
      )
      .padding(.horizontal, CloveSpacing.large)
   }
}

struct SearchTipRow: View {
   let icon: String
   let text: String
   
   var body: some View {
      HStack(alignment: .top, spacing: CloveSpacing.medium) {
         ZStack {
            Circle()
               .fill(CloveColors.secondaryText.opacity(0.1))
               .frame(width: 32, height: 32)
            
            Image(systemName: icon)
               .font(.system(size: 14, weight: .medium))
               .foregroundStyle(CloveColors.secondaryText)
         }
         
         Text(text)
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(CloveColors.secondaryText)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
         
         Spacer(minLength: 0)
      }
   }
}

struct TimelineFeatureRow: View {
   let icon: String
   let text: String
   let color: Color
   
   var body: some View {
      HStack(spacing: CloveSpacing.medium) {
         ZStack {
            Circle()
               .fill(color.opacity(0.1))
               .frame(width: 32, height: 32)
            
            Image(systemName: icon)
               .font(.system(size: 14, weight: .medium))
               .foregroundStyle(color)
         }
         
         Text(text)
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(CloveColors.secondaryText)
         
         Spacer()
      }
   }
}

#Preview {
   MedicationTimelineView()
}
