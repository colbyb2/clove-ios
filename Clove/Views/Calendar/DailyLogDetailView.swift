import SwiftUI

struct DailyLogDetailView: View {
    let log: DailyLog
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies
    @State private var bowelMovements: [BowelMovement] = []
    @State private var foodEntries: [FoodEntry] = []
    @State private var activityEntries: [ActivityEntry] = []
    @State private var cycleEntry: Cycle? = nil
    @State private var isFoodsExpanded: Bool = false
    @State private var isActivitiesExpanded: Bool = false
    @State private var isMedicationsExpanded: Bool = false
    @State private var isBowelMovementsExpanded: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CloveSpacing.large) {
                    headerSection

                    if hasAtAGlanceData {
                        atAGlanceSection
                    }

                    if !log.symptomRatings.isEmpty {
                        symptomsSection
                    }

                    if hasDailyDetails {
                        dailyDetailsSection
                    }

                    if let notes = log.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        notesSection(notes: notes)
                    }

                    if !hasAnyData {
                        EmptyStateView(
                            icon: "doc.text",
                            title: "No Data Recorded",
                            subtitle: "No information was logged for this day"
                        )
                    }
                }
                .padding(.horizontal, CloveSpacing.medium)
                .padding(.bottom, CloveSpacing.xlarge)
            }
            .background(CloveColors.background.ignoresSafeArea())
            .navigationTitle("Day details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Theme.shared.accent)
                    .fontWeight(.semibold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        editThisDay()
                    }
                    .foregroundStyle(Theme.shared.accent)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            loadBowelMovements()
            loadFoodEntries()
            loadActivityEntries()
            loadCycleEntry()
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack(alignment: .center, spacing: CloveSpacing.medium) {
            VStack(alignment: .leading, spacing: 3) {
                Text(log.date.formatted(.dateTime.weekday(.wide)))
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)

                Text(log.date.formatted(date: .long, time: .omitted))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(CloveColors.primaryText)
            }

            Spacer()

            if log.isFlareDay {
                Label("Flare day", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(CloveColors.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(CloveColors.orange.opacity(0.12), in: Capsule())
            }
        }
        .padding(.top, CloveSpacing.medium)
    }

    // MARK: - Day at a Glance
    private var atAGlanceSection: some View {
        VStack(spacing: CloveSpacing.medium) {
            SectionHeaderView(title: "Day at a glance", icon: "sparkles")

            if hasPhysicalMentalData {
                HStack(spacing: CloveSpacing.small) {
                    if let mood = log.mood {
                        DayMetricTile(
                            title: "Mood",
                            value: mood,
                            icon: CloveSymbols.mood(for: Double(mood)),
                            color: moodColor(for: mood)
                        )
                    }
                    if let pain = log.painLevel {
                        DayMetricTile(
                            title: "Pain",
                            value: pain,
                            icon: "cross.fill",
                            color: painColor(for: pain)
                        )
                    }
                    if let energy = log.energyLevel {
                        DayMetricTile(
                            title: "Energy",
                            value: energy,
                            icon: "bolt.fill",
                            color: energyColor(for: energy)
                        )
                    }
                }
            }

            if !contextItems.isEmpty {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 135), spacing: CloveSpacing.small)],
                    spacing: CloveSpacing.small
                ) {
                    ForEach(contextItems) { item in
                        DayContextItemView(item: item)
                    }
                }
            }
        }
    }
    
    // MARK: - Symptoms Section
    private var symptomsSection: some View {
        VStack(spacing: CloveSpacing.medium) {
            SectionHeaderView(title: "Symptoms", icon: CloveSymbols.symptom)

            VStack(spacing: 0) {
                ForEach(log.symptomRatings, id: \.symptomId) { symptom in
                    SymptomSummaryRow(symptom: symptom, color: symptomColor(for: symptom.rating))

                    if symptom.symptomId != log.symptomRatings.last?.symptomId {
                        Divider()
                            .padding(.leading, CloveSpacing.medium)
                    }
                }
            }
            .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.medium))
        }
    }

    // MARK: - Daily Details
    private var dailyDetailsSection: some View {
        VStack(spacing: CloveSpacing.medium) {
            SectionHeaderView(title: "Daily details", icon: "list.bullet.rectangle")

            VStack(spacing: CloveSpacing.small) {
                if !foodEntries.isEmpty {
                    FoodEntriesDetailSection(entries: foodEntries, isExpanded: $isFoodsExpanded)
                }

                if !activityEntries.isEmpty {
                    ActivityEntriesDetailSection(entries: activityEntries, isExpanded: $isActivitiesExpanded)
                }

                if !log.medicationAdherence.isEmpty {
                    DailyDetailDisclosure(
                        title: "Medications",
                        summary: medicationSummary,
                        icon: CloveSymbols.medication,
                        isExpanded: $isMedicationsExpanded
                    ) {
                        MedicationAdherenceView(adherence: log.medicationAdherence)
                    }
                }

                if !bowelMovements.isEmpty {
                    DailyDetailDisclosure(
                        title: "Bowel movements",
                        summary: entryCountText(bowelMovements.count),
                        icon: CloveSymbols.bowelMovement,
                        isExpanded: $isBowelMovementsExpanded
                    ) {
                        bowelMovementRows
                    }
                }
            }
        }
    }
    
    // MARK: - Notes Section
    private func notesSection(notes: String) -> some View {
        VStack(spacing: CloveSpacing.medium) {
            SectionHeaderView(title: "Notes", icon: CloveSymbols.notes)
            NotesDisplayView(notes: notes)
        }
    }
    
    private var bowelMovementRows: some View {
        VStack(spacing: CloveSpacing.small) {
            ForEach(bowelMovements.sorted(by: { $0.date < $1.date })) { movement in
                    HStack(spacing: CloveSpacing.medium) {
                        // Bristol stool type indicator
                        VStack {
                            Text("\(Int(movement.type))")
                                .font(.system(.title2, design: .rounded).weight(.bold))
                                .foregroundStyle(bristolTypeColor(for: movement.bristolStoolType))
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(bristolTypeColor(for: movement.bristolStoolType).opacity(0.2))
                                )
                        }
                        
                        // Type description
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Type \(Int(movement.type))")
                                .font(CloveFonts.body())
                                .foregroundStyle(CloveColors.primaryText)
                                .fontWeight(.medium)
                            
                            Text(movement.bristolStoolType.description)
                                .font(CloveFonts.small())
                                .foregroundStyle(CloveColors.secondaryText)
                                .lineLimit(2)
                            
                            Text(movement.bristolStoolType.consistency)
                                .font(CloveFonts.small())
                                .foregroundStyle(bristolTypeColor(for: movement.bristolStoolType))
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(bristolTypeColor(for: movement.bristolStoolType).opacity(0.1))
                                )
                        }
                        
                        Spacer()
                        
                        // Time
                        Text(movement.date.formatted(date: .omitted, time: .shortened))
                            .font(CloveFonts.small())
                            .foregroundStyle(CloveColors.secondaryText)
                    }
                    .padding(.horizontal, CloveSpacing.medium)
                    .padding(.vertical, CloveSpacing.small)
                    .background(
                        RoundedRectangle(cornerRadius: CloveCorners.small)
                            .fill(CloveColors.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: CloveCorners.small)
                                    .stroke(bristolTypeColor(for: movement.bristolStoolType).opacity(0.2), lineWidth: 1)
                            )
                    )
                }
            }
        }

    // MARK: - Helper Properties
    private var hasPhysicalMentalData: Bool {
        log.mood != nil || log.painLevel != nil || log.energyLevel != nil
    }

    private var hasAtAGlanceData: Bool {
        hasPhysicalMentalData || !contextItems.isEmpty
    }

    private var hasDailyDetails: Bool {
        !foodEntries.isEmpty || !activityEntries.isEmpty ||
        !log.medicationAdherence.isEmpty || !bowelMovements.isEmpty
    }

    private var contextItems: [DayContextItem] {
        var items: [DayContextItem] = []

        if let weather = log.weather {
            items.append(
                DayContextItem(
                    id: "weather",
                    title: "Weather",
                    value: weather,
                    icon: CloveSymbols.weather(for: weather),
                    color: weatherAccentColor(for: weather)
                )
            )
        }

        if let waterIntake = log.waterIntake, waterIntake > 0 {
            items.append(
                DayContextItem(
                    id: "hydration",
                    title: "Hydration",
                    value: HydrationPreferences.unit().formatted(canonicalOunces: waterIntake),
                    icon: "drop.fill",
                    color: CloveColors.blue
                )
            )
        }

        if let cycle = cycleEntry {
            let prefix = cycle.isStartOfCycle ? "Day 1 · " : ""
            items.append(
                DayContextItem(
                    id: "cycle",
                    title: "Cycle",
                    value: "\(prefix)\(cycle.flow.displayName) flow",
                    icon: flowIcon(for: cycle.flow),
                    color: flowColor(for: cycle.flow)
                )
            )

            if cycle.hasCramps {
                items.append(
                    DayContextItem(
                        id: "cramps",
                        title: "Cycle symptom",
                        value: "Cramps",
                        icon: "bolt.heart.fill",
                        color: CloveColors.orange
                    )
                )
            }
        }

        return items
    }

    private var medicationSummary: String {
        let adherence = log.medicationAdherence
        let taken = adherence.filter(\.wasTaken).count
        return "\(taken) of \(adherence.count) taken"
    }

    private func entryCountText(_ count: Int) -> String {
        "\(count) \(count == 1 ? "entry" : "entries")"
    }

    private var hasAnyData: Bool {
        hasAtAGlanceData || !log.symptomRatings.isEmpty || hasDailyDetails ||
        (log.notes != nil && !log.notes!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ||
        log.isFlareDay
    }

    // MARK: - Helper Functions
    private func loadBowelMovements() {
        bowelMovements = dependencies.bowelMovementRepository.getBowelMovementsForDate(log.date)
    }

    private func loadFoodEntries() {
        foodEntries = dependencies.foodEntryRepository.getEntriesForDate(log.date)
    }

    private func loadActivityEntries() {
        activityEntries = dependencies.activityEntryRepository.getEntriesForDate(log.date)
    }

    private func loadCycleEntry() {
        let cycles = dependencies.cycleRepository.getCyclesForDate(log.date)
        cycleEntry = cycles.first
    }

    private func editThisDay() {
        // Navigate to Today tab and set the date for editing
        dependencies.navigationCoordinator.editDayInTodayView(date: log.date)
        
        // Dismiss this view
        dismiss()
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func moodColor(for mood: Int) -> Color {
        switch mood {
        case 9...10: return Color(red: 0.2, green: 0.78, blue: 0.55)
        case 7...8: return Color(red: 0.3, green: 0.72, blue: 0.65)
        case 5...6: return Color(red: 1.0, green: 0.75, blue: 0.3)
        case 3...4: return Color(red: 0.95, green: 0.5, blue: 0.3)
        default: return Color(red: 0.85, green: 0.25, blue: 0.35)
        }
    }
    
    private func painColor(for pain: Int) -> Color {
        switch pain {
        case 8...10: return Color(red: 0.9, green: 0.2, blue: 0.25)
        case 5...7: return Color(red: 0.95, green: 0.52, blue: 0.2)
        case 3...4: return Color(red: 1.0, green: 0.8, blue: 0.4)
        case 1...2: return Color(red: 0.4, green: 0.85, blue: 0.65)
        default: return Color(red: 0.35, green: 0.75, blue: 0.85)
        }
    }
    
    private func energyColor(for energy: Int) -> Color {
        switch energy {
        case 8...10: return Color(red: 1.0, green: 0.85, blue: 0.2)
        case 5...7: return Color(red: 0.25, green: 0.7, blue: 0.95)
        case 3...4: return Color(red: 0.65, green: 0.6, blue: 0.85)
        case 1...2: return Color(red: 0.5, green: 0.5, blue: 0.7)
        default: return Color(red: 0.35, green: 0.35, blue: 0.55)
        }
    }
    
    private func symptomColor(for rating: Int) -> Color {
        painColor(for: rating) // Use same color scale as pain
    }
    
    private func bristolTypeColor(for type: BristolStoolType) -> Color {
        switch type.consistency {
        case "Hard": return CloveColors.red
        case "Normal": return CloveColors.green
        case "Loose": return CloveColors.orange
        default: return CloveColors.blue
        }
    }
    
    private func weatherAccentColor(for weather: String) -> Color {
        switch weather {
        case "Sunny": return Color.yellow
        case "Cloudy", "Gloomy": return Color.gray
        case "Rainy": return CloveColors.blue
        case "Stormy": return Color.purple
        case "Snow": return Color.cyan
        default: return CloveColors.blue
        }
    }

    private func flowColor(for flow: FlowLevel) -> Color {
        switch flow {
        case .spotting: return .pink.opacity(0.6)
        case .light: return .pink
        case .medium: return .red
        case .heavy: return .red.opacity(0.9)
        case .veryHeavy: return .purple
        }
    }

    private func flowIcon(for flow: FlowLevel) -> String {
        switch flow {
        case .spotting, .light: return "drop"
        case .medium, .heavy: return "drop.fill"
        case .veryHeavy: return "drop.triangle.fill"
        }
    }
}

private struct DayMetricTile: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text("\(value)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
            }
            .foregroundStyle(color)

            Text(title)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(CloveColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CloveSpacing.medium)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: CloveCorners.medium))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value) out of 10")
    }
}

private struct DayContextItem: Identifiable {
    let id: String
    let title: String
    let value: String
    let icon: String
    let color: Color
}

private struct DayContextItemView: View {
    let item: DayContextItem

    var body: some View {
        HStack(spacing: CloveSpacing.small) {
            Image(systemName: item.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(item.color)
                .frame(width: 32, height: 32)
                .background(item.color.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(CloveColors.secondaryText)
                Text(item.value)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(CloveColors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
        .padding(CloveSpacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.medium))
    }
}

private struct SymptomSummaryRow: View {
    let symptom: SymptomRating
    let color: Color

    var body: some View {
        HStack(spacing: CloveSpacing.medium) {
            VStack(alignment: .leading, spacing: 7) {
                Text(symptom.symptomName)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(CloveColors.primaryText)

                if !symptom.isBinary {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(CloveColors.background)
                            Capsule()
                                .fill(color)
                                .frame(width: geometry.size.width * Double(symptom.rating) / 10)
                        }
                    }
                    .frame(height: 5)
                }
            }

            Spacer()

            if symptom.isBinary {
                Label(
                    symptom.rating > 0 ? "Present" : "Not present",
                    systemImage: symptom.rating > 0 ? "checkmark.circle.fill" : "minus.circle"
                )
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(symptom.rating > 0 ? color : CloveColors.secondaryText)
            } else {
                Text("\(symptom.rating)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(color)
                + Text(" / 10")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(CloveColors.secondaryText)
            }
        }
        .padding(CloveSpacing.medium)
        .accessibilityElement(children: .combine)
    }
}

private struct DailyDetailDisclosure<Content: View>: View {
    let title: String
    let summary: String
    let icon: String
    @Binding var isExpanded: Bool
    let content: Content

    init(
        title: String,
        summary: String,
        icon: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.summary = summary
        self.icon = icon
        self._isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        VStack(spacing: CloveSpacing.small) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: CloveSpacing.small) {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.shared.accent)
                        .frame(width: 28, height: 28)
                        .background(Theme.shared.accent.opacity(0.1), in: Circle())

                    Text(title)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(CloveColors.primaryText)

                    Spacer()

                    Text(summary)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(CloveColors.secondaryText)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(CloveSpacing.medium)
        .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.medium))
    }
}

// MARK: - Binary Symptom Display View
struct BinarySymptomDisplayView: View {
    let label: String
    let isPresent: Bool

    var body: some View {
        HStack(spacing: CloveSpacing.medium) {
            // Symptom name
            Text(label)
                .font(CloveFonts.body())
                .foregroundStyle(CloveColors.primaryText)
                .fontWeight(.medium)

            Spacer()

            // Yes/No indicator
            HStack(spacing: CloveSpacing.small) {
                Image(systemName: isPresent ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(isPresent ? Theme.shared.accent : Color.gray)

                Text(isPresent ? "Yes" : "No")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(isPresent ? Theme.shared.accent : Color.gray)
            }
            .frame(minWidth: 60)
            .padding(.horizontal, CloveSpacing.medium)
            .padding(.vertical, CloveSpacing.small)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.small)
                    .fill(isPresent ? Theme.shared.accent.opacity(0.1) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: CloveCorners.small)
                            .stroke(isPresent ? Theme.shared.accent.opacity(0.3) : Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, CloveSpacing.medium)
        .padding(.vertical, CloveSpacing.small)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.small)
                .fill(CloveColors.card)
        )
    }
}

// MARK: - Medication Adherence View
struct MedicationAdherenceView: View {
    let adherence: [MedicationAdherence]

    var body: some View {
        VStack(spacing: CloveSpacing.small) {
            ForEach(adherence.indices, id: \.self) { index in
                let medication = adherence[index]

                HStack(spacing: CloveSpacing.medium) {
                       // Status indicator
                       Image(systemName: medication.wasTaken ? "checkmark.circle.fill" : "circle")
                           .font(.system(size: 20))
                           .foregroundStyle(medication.wasTaken ? CloveColors.success : CloveColors.secondaryText)

                       // Medication info
                       VStack(alignment: .leading, spacing: 2) {
                           Text(medication.medicationName)
                               .font(CloveFonts.body())
                               .foregroundStyle(CloveColors.primaryText)
                               .fontWeight(.medium)

                           if medication.isAsNeeded || medication.medicationId == -1 {
                               Text(medication.medicationId == -1 ? "One-time" : "As needed")
                                   .font(CloveFonts.small())
                                   .foregroundStyle(CloveColors.secondaryText)
                                   .padding(.horizontal, 6)
                                   .padding(.vertical, 2)
                                   .background(
                                       RoundedRectangle(cornerRadius: 4)
                                           .fill(CloveColors.secondaryText.opacity(0.1))
                                   )
                           }
                       }

                       Spacer()

                       // Status text
                       Text(medication.wasTaken ? "Taken" : "Not taken")
                           .font(CloveFonts.small())
                           .foregroundStyle(medication.wasTaken ? CloveColors.success : CloveColors.secondaryText)
                           .fontWeight(.medium)
                   }
                   .padding(.horizontal, CloveSpacing.medium)
                   .padding(.vertical, CloveSpacing.small)
                   .background(
                       RoundedRectangle(cornerRadius: CloveCorners.small)
                           .fill(medication.wasTaken ? CloveColors.success.opacity(0.05) : CloveColors.card)
                           .overlay(
                               RoundedRectangle(cornerRadius: CloveCorners.small)
                                   .stroke(medication.wasTaken ? CloveColors.success.opacity(0.2) : Color.clear, lineWidth: 1)
                           )
                   )
            }
        }
    }
}

// MARK: - Food Entries Detail Section
struct FoodEntriesDetailSection: View {
    let entries: [FoodEntry]
    @Binding var isExpanded: Bool

    var body: some View {
        DailyDetailDisclosure(
            title: "Meals",
            summary: "\(entries.count) \(entries.count == 1 ? "entry" : "entries")",
            icon: CloveSymbols.meals,
            isExpanded: $isExpanded
        ) {
            VStack(spacing: CloveSpacing.xsmall) {
                ForEach(entries.sorted(by: { $0.date < $1.date })) { entry in
                    FoodEntryDetailRow(entry: entry)
                }
            }
        }
    }
}

struct FoodEntryDetailRow: View {
    let entry: FoodEntry

    var body: some View {
        HStack(spacing: CloveSpacing.small) {
            // Category icon
            Image(systemName: entry.category.icon)
                .font(.system(size: 12))
                .foregroundStyle(categoryColor)
                .frame(width: 24, height: 24)
                .background(categoryColor.opacity(0.15))
                .clipShape(Circle())

            // Name and details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.name)
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(CloveColors.primaryText)

                    if entry.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.yellow)
                    }
                }

                HStack(spacing: 6) {
                    Text(entry.category.displayName)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(categoryColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(categoryColor.opacity(0.1)))

                    Text(entry.formattedTime)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)
                }
            }

            Spacer()
        }
        .padding(.horizontal, CloveSpacing.medium)
        .padding(.vertical, CloveSpacing.xsmall)
        .background(CloveColors.card.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
    }

    private var categoryColor: Color {
        switch entry.category {
        case .breakfast: return CloveColors.orange
        case .lunch: return CloveColors.green
        case .dinner: return CloveColors.blue
        case .snack: return Theme.shared.accent
        case .beverage: return CloveColors.blue.opacity(0.8)
        }
    }
}

// MARK: - Activity Entries Detail Section
struct ActivityEntriesDetailSection: View {
    let entries: [ActivityEntry]
    @Binding var isExpanded: Bool

    var body: some View {
        DailyDetailDisclosure(
            title: "Activities",
            summary: totalDuration > 0
                ? formattedTotalDuration
                : "\(entries.count) \(entries.count == 1 ? "entry" : "entries")",
            icon: CloveSymbols.activities,
            isExpanded: $isExpanded
        ) {
            VStack(spacing: CloveSpacing.xsmall) {
                ForEach(entries.sorted(by: { $0.date < $1.date })) { entry in
                    ActivityEntryDetailRow(entry: entry)
                }
            }
        }
    }

    private var totalDuration: Int {
        entries.compactMap { $0.duration }.reduce(0, +)
    }

    private var formattedTotalDuration: String {
        if totalDuration < 60 {
            return "\(totalDuration) min total"
        } else {
            let hours = totalDuration / 60
            let minutes = totalDuration % 60
            if minutes == 0 {
                return "\(hours)h total"
            } else {
                return "\(hours)h \(minutes)m total"
            }
        }
    }
}

struct ActivityEntryDetailRow: View {
    let entry: ActivityEntry

    var body: some View {
        let category = entry.categoryDefinition
        HStack(spacing: CloveSpacing.small) {
            // Category icon
            Image(systemName: category.symbol)
                .font(.system(size: 12))
                .foregroundStyle(categoryColor)
                .frame(width: 24, height: 24)
                .background(categoryColor.opacity(0.15))
                .clipShape(Circle())

            // Name and details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.name)
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(CloveColors.primaryText)

                    if entry.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.yellow)
                    }
                }

                HStack(spacing: 6) {
                    Text(category.name)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(categoryColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(categoryColor.opacity(0.1)))

                    if let duration = entry.formattedDuration {
                        Text(duration)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(CloveColors.secondaryText)
                    }

                    if let intensity = entry.intensity {
                        Text(intensity.indicator)
                            .font(.system(size: 10))
                            .foregroundStyle(intensityColor(intensity))
                    }

                    Text(entry.formattedTime)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)
                }
            }

            Spacer()
        }
        .padding(.horizontal, CloveSpacing.medium)
        .padding(.vertical, CloveSpacing.xsmall)
        .background(CloveColors.card.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
    }

    private var categoryColor: Color {
        entry.categoryDefinition.color
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
    DailyLogDetailView(
        log: DailyLog(
            date: Date(),
            mood: 7,
            painLevel: 4,
            energyLevel: 8,
            meals: ["Breakfast", "Lunch", "Dinner"],
            activities: ["Walking", "Reading"],
            medicationsTaken: ["Ibuprofen", "Vitamin D"],
            notes: "Had a good day overall. Felt energetic in the morning but pain increased in the afternoon. The weather was nice so I was able to go for a walk.",
            isFlareDay: false,
            weather: "Sunny",
            symptomRatings: [
                SymptomRating(symptomId: 1, symptomName: "Headache", rating: 3, isBinary: false),
                SymptomRating(symptomId: 2, symptomName: "Fatigue", rating: 6, isBinary: false),
                SymptomRating(symptomId: 3, symptomName: "Nausea", rating: 10, isBinary: true),
                SymptomRating(symptomId: 4, symptomName: "Dizziness", rating: 0, isBinary: true)
            ]
        )
    )
}
