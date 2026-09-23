import SwiftUI

struct HistoryCalendarView: View {
    @Environment(\.dependencies) private var dependencies
    @AppStorage(Constants.HYDRATION_GOAL_OUNCES) private var hydrationGoalOunces = 64
    @AppStorage(Constants.HYDRATION_GOAL_ENABLED) private var hydrationGoalEnabled = true
    @AppStorage(Constants.HYDRATION_UNIT) private var hydrationUnitRawValue = HydrationUnit.fluidOunces.rawValue
    @State private var viewModel: HistoryCalendarViewModel
    @State private var currentMonth = Date()
    @State private var selectedDay: Date? = Calendar.current.startOfDay(for: Date())
    @State private var presentedDate: Date?
    @State private var showsCycleOverlay = true

    init(viewModel: HistoryCalendarViewModel = HistoryCalendarViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: CloveSpacing.medium) {
                if let error = viewModel.loadError {
                    RepositoryErrorView(
                        title: "We couldn't load your history",
                        error: error,
                        onRetry: viewModel.loadData
                    )
                }

                if viewModel.hasLoadedData {
                    controls

                    if viewModel.selectedCategory != .allData {
                        ColorLegendView(
                            category: viewModel.selectedCategory,
                            trackedSymptoms: viewModel.trackedSymptoms,
                            hydrationGoalOunces: hydrationGoalOunces,
                            hydrationGoalEnabled: hydrationGoalEnabled,
                            hydrationUnit: hydrationUnit
                        )
                        .padding(.horizontal, CloveSpacing.small)
                    }

                    CalendarView(
                        records: getCalendarRecords(),
                        onDaySelected: { date in
                            viewModel.selectedDate = date
                            selectedDay = date
                        },
                        selectedDate: $currentMonth,
                        selectedDay: $selectedDay,
                        showsCycleOverlay: showsCycleOverlay
                    )

                    if let selectedDay {
                        dayPreview(for: selectedDay)
                    } else {
                        Text("Select a day to see a quick summary.")
                            .font(CloveFonts.small())
                            .foregroundStyle(CloveColors.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, CloveSpacing.medium)
                    }

                    MonthSnapshotCard(
                        title: currentMonth.formatted(.dateTime.month(.wide)),
                        daysRecorded: recordedDayCount,
                        flareDays: flareDayCount,
                        cycleDays: cycleDayCount,
                        metricSummary: metricMonthSummary
                    )
                } else if viewModel.loadError == nil {
                    ProgressView("Loading your history...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                }
            }
            .padding(.horizontal, CloveSpacing.medium)
            .padding(.bottom, 110)
        }
        .background(CloveColors.background)
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // Only show "Today" button when not viewing current month
                if !Calendar.current.isDate(currentMonth, equalTo: Date(), toGranularity: .month) {
                    Button("Today") {
                        withAnimation {
                            currentMonth = Date()
                            selectedDay = Calendar.current.startOfDay(for: Date())
                            viewModel.selectedDate = selectedDay
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.shared.accent)
                }
            }
        }
        .onAppear {
            viewModel.loadData()
            viewModel.selectedDate = selectedDay
            if dependencies.tutorialManager.startTutorial(Tutorials.CalendarView) == .Failure {
                print("Tutorial [CalendarView] Failed to Start")
            }
        }
        .sheet(item: $presentedDate) { date in
            if let log = viewModel.log(for: date) {
                DailyLogDetailView(log: log)
            } else if viewModel.hasAnyData(for: date) {
                DailyLogDetailView(log: DailyLog(date: date))
            } else {
                EmptyLogView(date: date)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: CloveSpacing.small) {
            CategoryPickerView(
                categories: viewModel.availableCategories,
                selectedCategory: $viewModel.selectedCategory
            )

            if viewModel.userSettings.trackCycle {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showsCycleOverlay.toggle()
                    }
                } label: {
                    Image(systemName: showsCycleOverlay ? "drop.fill" : "drop")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(showsCycleOverlay ? Color.pink : CloveColors.secondaryText)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(CloveColors.card))
                        .overlay(Circle().stroke(CloveColors.secondaryText.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showsCycleOverlay ? "Hide cycle overlay" : "Show cycle overlay")
            }
        }
    }

    private var hydrationUnit: HydrationUnit {
        HydrationUnit(rawValue: hydrationUnitRawValue) ?? .fluidOunces
    }

    private var monthSummaries: [HistoryDaySummary] {
        viewModel.daySummariesByDate.values.filter {
            Calendar.current.isDate($0.date, equalTo: currentMonth, toGranularity: .month)
        }
    }

    private var monthLogs: [DailyLog] {
        monthSummaries.compactMap(\.log)
    }

    private var recordedDayCount: Int {
        monthSummaries.filter(\.hasAnyData).count
    }

    private var flareDayCount: Int {
        monthLogs.filter(\.isFlareDay).count
    }

    private var cycleDayCount: Int {
        guard viewModel.userSettings.trackCycle else { return 0 }
        return viewModel.cyclesByDate.keys.filter {
            Calendar.current.isDate($0, equalTo: currentMonth, toGranularity: .month)
        }.count
    }

    private var metricMonthSummary: String? {
        switch viewModel.selectedCategory {
        case .allData:
            return nil
        case .mood:
            return averageSummary(values: monthLogs.compactMap(\.mood), label: "average mood")
        case .pain:
            return averageSummary(values: monthLogs.compactMap(\.painLevel), label: "average pain")
        case .energy:
            return averageSummary(values: monthLogs.compactMap(\.energyLevel), label: "average energy")
        case .hydration:
            let values = monthLogs.compactMap(\.waterIntake).filter { $0 > 0 }
            guard !values.isEmpty else { return nil }
            return "\(hydrationUnit.formatted(canonicalOunces: values.reduce(0, +) / values.count)) average hydration"
        case .meals:
            let total = monthSummaries.reduce(0) { $0 + mealCount(in: $1) }
            return total > 0 ? "\(total) meal entr\(total == 1 ? "y" : "ies")" : nil
        case .activities:
            let total = monthSummaries.reduce(0) { $0 + activityCount(in: $1) }
            return total > 0 ? "\(total) activit\(total == 1 ? "y" : "ies")" : nil
        case .medications:
            let total = monthLogs.reduce(0) { $0 + medicationCount(in: $1) }
            return total > 0 ? "\(total) medication entr\(total == 1 ? "y" : "ies")" : nil
        case .bowelMovements:
            let total = monthSummaries.reduce(0) { $0 + $1.bowelMovements.count }
            return total > 0 ? "\(total) bowel movement\(total == 1 ? "" : "s")" : nil
        case .symptom(let id, let name):
            let values = monthLogs.flatMap(\.symptomRatings).filter { $0.symptomId == id }.map(\.rating)
            return averageSummary(values: values, label: "average \(name.lowercased())")
        }
    }

    private func averageSummary(values: [Int], label: String) -> String? {
        guard !values.isEmpty else { return nil }
        let average = Double(values.reduce(0, +)) / Double(values.count)
        return "\(average.formatted(.number.precision(.fractionLength(1)))) \(label)"
    }

    @ViewBuilder
    private func dayPreview(for date: Date) -> some View {
        let day = Calendar.current.startOfDay(for: date)
        let summary = viewModel.daySummariesByDate[day]
        let log = summary?.log
        let cycle = viewModel.cyclesByDate[day]
        let metrics = previewMetrics(log: log)
        let details = previewDetails(summary: summary, log: log)
        let hasData = (summary?.hasAnyData ?? false) || cycle != nil

        HistoryDayPreviewCard(
            date: day,
            hasData: hasData,
            metrics: metrics,
            details: details,
            note: log?.notes,
            cycleDescription: cycle.map { "Period · \($0.flow.displayName) flow" },
            onView: { presentedDate = day },
            onEdit: { dependencies.navigationCoordinator.editDayInTodayView(date: day) }
        )
    }

    private func previewMetrics(log: DailyLog?) -> [HistoryPreviewMetric] {
        guard let log else { return [] }
        return [
            log.mood.map {
                HistoryPreviewMetric(
                    title: "Mood",
                    value: "\($0)",
                    icon: CloveSymbols.mood(for: Double($0)),
                    color: overviewMoodColor(for: $0)
                )
            },
            log.painLevel.map {
                HistoryPreviewMetric(
                    title: "Pain",
                    value: "\($0)",
                    icon: "cross.fill",
                    color: overviewPainColor(for: $0)
                )
            },
            log.energyLevel.map {
                HistoryPreviewMetric(
                    title: "Energy",
                    value: "\($0)",
                    icon: "bolt.fill",
                    color: overviewEnergyColor(for: $0)
                )
            }
        ].compactMap { $0 }
    }

    private func overviewMoodColor(for value: Int) -> Color {
        switch value {
        case 9...10: return Color(red: 0.2, green: 0.78, blue: 0.55)
        case 7...8: return Color(red: 0.3, green: 0.72, blue: 0.65)
        case 5...6: return Color(red: 1.0, green: 0.75, blue: 0.3)
        case 3...4: return Color(red: 0.95, green: 0.5, blue: 0.3)
        default: return Color(red: 0.85, green: 0.25, blue: 0.35)
        }
    }

    private func overviewPainColor(for value: Int) -> Color {
        switch value {
        case 8...10: return Color(red: 0.9, green: 0.2, blue: 0.25)
        case 5...7: return Color(red: 0.95, green: 0.52, blue: 0.2)
        case 3...4: return Color(red: 1.0, green: 0.8, blue: 0.4)
        case 1...2: return Color(red: 0.4, green: 0.85, blue: 0.65)
        default: return Color(red: 0.35, green: 0.75, blue: 0.85)
        }
    }

    private func overviewEnergyColor(for value: Int) -> Color {
        switch value {
        case 8...10: return Color(red: 1.0, green: 0.85, blue: 0.2)
        case 5...7: return Color(red: 0.25, green: 0.7, blue: 0.95)
        case 3...4: return Color(red: 0.65, green: 0.6, blue: 0.85)
        case 1...2: return Color(red: 0.5, green: 0.5, blue: 0.7)
        default: return Color(red: 0.35, green: 0.35, blue: 0.55)
        }
    }

    private func previewDetails(summary: HistoryDaySummary?, log: DailyLog?) -> [String] {
        guard let summary else { return [] }
        var details: [String] = []

        if let log {
            details.append(contentsOf: log.symptomRatings.prefix(3).map { rating in
                rating.isBinary ? "\(rating.symptomName): \(rating.rating > 0 ? "present" : "absent")" : "\(rating.symptomName) \(rating.rating)"
            })
            if let water = log.waterIntake, water > 0 {
                details.append(hydrationUnit.formatted(canonicalOunces: water))
            }
        }

        let meals = mealCount(in: summary)
        if meals > 0 { details.append("\(meals) meal\(meals == 1 ? "" : "s")") }
        let activities = activityCount(in: summary)
        if activities > 0 { details.append("\(activities) activit\(activities == 1 ? "y" : "ies")") }
        if !summary.bowelMovements.isEmpty {
            details.append("\(summary.bowelMovements.count) bowel movement\(summary.bowelMovements.count == 1 ? "" : "s")")
        }
        if let log, medicationCount(in: log) > 0 {
            details.append("\(medicationCount(in: log)) medication entr\(medicationCount(in: log) == 1 ? "y" : "ies")")
        }

        return Array(details.prefix(5))
    }

    private func mealCount(in summary: HistoryDaySummary) -> Int {
        summary.foodEntries.count + (summary.log?.meals.count ?? 0)
    }

    private func activityCount(in summary: HistoryDaySummary) -> Int {
        summary.activityEntries.count + (summary.log?.activities.count ?? 0)
    }

    private func medicationCount(in log: DailyLog) -> Int {
        max(log.medicationsTaken.count, log.medicationAdherence.count)
    }
    
    func getCalendarRecords() -> [Date: CalendarRecord] {
        // Day summaries include DailyLog plus current food, activity, and bowel tables.
        var allDates = Set(viewModel.daySummariesByDate.keys).union(Set(viewModel.cyclesByDate.keys))
        
        // Add predicted cycle dates if prediction exists
        let predictedDates = getPredictedCycleDates()
        allDates = allDates.union(predictedDates)
        
        var records: [Date: CalendarRecord] = [:]
        for date in allDates {
            let log = viewModel.logsByDate[date]
            let isPredicted = predictedDates.contains(date)
            
            // Only show cycle indicator if the feature is enabled
            let hasCycle = viewModel.userSettings.trackCycle && viewModel.cyclesByDate[date] != nil
            
            let color: Color
            if viewModel.selectedCategory == .allData {
                color = .clear
            } else if viewModel.selectedCategory == .bowelMovements {
                color = bowelMovementColor(for: viewModel.bowelMovements(for: date))
            } else if viewModel.selectedCategory == .meals {
                color = viewModel.hasMeals(for: date) ? Theme.shared.accent.opacity(0.75) : .clear
            } else if viewModel.selectedCategory == .activities {
                color = viewModel.hasActivities(for: date) ? Theme.shared.accent.opacity(0.75) : .clear
            } else if let log {
                color = getLogColor(log: log)
            } else {
                color = .clear
            }
            
            records[date] = CalendarRecord(
                color: color,
                icon: nil,
                hasCycleEntry: hasCycle,
                isPredictedCycle: isPredicted,
                hasData: viewModel.hasAnyData(for: date),
                isFlareDay: log?.isFlareDay ?? false,
                valueLabel: calendarValueLabel(for: date, log: log),
                accessibilityValue: calendarAccessibilityValue(for: date, log: log)
            )
        }
        
        return records
    }

    private func calendarValueLabel(for date: Date, log: DailyLog?) -> String? {
        switch viewModel.selectedCategory {
        case .allData: return nil
        case .mood: return log?.mood.map(String.init)
        case .pain: return log?.painLevel.map(String.init)
        case .energy: return log?.energyLevel.map(String.init)
        case .hydration:
            guard let value = log?.waterIntake, value > 0 else { return nil }
            return hydrationUnit.formatted(canonicalOunces: value)
        case .meals:
            guard let summary = viewModel.daySummariesByDate[date] else { return nil }
            let count = mealCount(in: summary)
            return count > 0 ? "\(count)" : nil
        case .activities:
            guard let summary = viewModel.daySummariesByDate[date] else { return nil }
            let count = activityCount(in: summary)
            return count > 0 ? "\(count)" : nil
        case .medications:
            guard let log else { return nil }
            let count = medicationCount(in: log)
            return count > 0 ? "\(count)" : nil
        case .bowelMovements:
            let count = viewModel.bowelMovements(for: date).count
            return count > 0 ? "\(count)" : nil
        case .symptom(let id, _):
            guard let rating = log?.symptomRatings.first(where: { $0.symptomId == id }) else { return nil }
            return rating.isBinary ? (rating.rating > 0 ? "Yes" : "No") : "\(rating.rating)"
        }
    }

    private func calendarAccessibilityValue(for date: Date, log: DailyLog?) -> String? {
        guard let value = calendarValueLabel(for: date, log: log) else { return nil }
        return "\(viewModel.selectedCategory.displayName) \(value)"
    }
    
    /// Get the set of dates that are part of the predicted cycle
    private func getPredictedCycleDates() -> Set<Date> {
        guard let prediction = viewModel.cyclePrediction,
              viewModel.userSettings.trackCycle else {
            return []
        }
        
        
        let calendar = Calendar.current
        var dates: Set<Date> = []
        
        for dayOffset in 0..<(prediction.length ?? 1) {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: prediction.startDate) {
                dates.insert(calendar.startOfDay(for: date))
            }
        }
        
        return dates
    }
    
    func getLogColor(log: DailyLog) -> Color {
        switch viewModel.selectedCategory {
        case .allData:
            // Show a general indicator if any data exists
            if log.mood != nil || log.painLevel != nil || log.energyLevel != nil ||
                (log.waterIntake ?? 0) > 0 || !log.symptomRatings.isEmpty {
                return Theme.shared.accent.opacity(0.7)
            }
            return .clear
            
        case .mood:
            if let mood = log.mood {
                switch mood {
                    // Best mood: Vibrant emerald green
                case 9...10: return Color(red: 0.2, green: 0.78, blue: 0.55).opacity(0.9)
                    // Good mood: Fresh teal
                case 7...8: return Color(red: 0.3, green: 0.72, blue: 0.65).opacity(0.85)
                    // Neutral mood: Warm amber
                case 5...6: return Color(red: 1.0, green: 0.75, blue: 0.3).opacity(0.8)
                    // Poor mood: Coral orange
                case 3...4: return Color(red: 0.95, green: 0.5, blue: 0.3).opacity(0.85)
                    // Worst mood: Deep rose red
                case 0...2: return Color(red: 0.85, green: 0.25, blue: 0.35).opacity(0.9)
                default: return .gray.opacity(0.5)
                }
            }
            
        case .pain:
            if let pain = log.painLevel {
                switch pain {
                    // Severe pain: Intense crimson red
                case 8...10: return Color(red: 0.9, green: 0.2, blue: 0.25).opacity(0.92)
                    // Moderate pain: Vibrant orange
                case 5...7: return Color(red: 0.95, green: 0.52, blue: 0.2).opacity(0.88)
                    // Mild pain: Soft peach-yellow
                case 3...4: return Color(red: 1.0, green: 0.8, blue: 0.4).opacity(0.75)
                    // Minimal pain: Cool mint green
                case 1...2: return Color(red: 0.4, green: 0.85, blue: 0.65).opacity(0.7)
                    // No pain: Serene aqua blue
                case 0: return Color(red: 0.35, green: 0.75, blue: 0.85).opacity(0.65)
                default: return .gray.opacity(0.5)
                }
            }
            
        case .energy:
            if let energy = log.energyLevel {
                switch energy {
                    // High energy: Radiant golden yellow
                case 8...10: return Color(red: 1.0, green: 0.85, blue: 0.2).opacity(0.9)
                    // Good energy: Bright sky blue
                case 5...7: return Color(red: 0.25, green: 0.7, blue: 0.95).opacity(0.85)
                    // Low energy: Soft lavender
                case 3...4: return Color(red: 0.65, green: 0.6, blue: 0.85).opacity(0.75)
                    // Very low energy: Muted slate blue
                case 1...2: return Color(red: 0.5, green: 0.5, blue: 0.7).opacity(0.7)
                    // Exhausted: Deep indigo
                case 0: return Color(red: 0.35, green: 0.35, blue: 0.55).opacity(0.85)
                default: return .gray.opacity(0.5)
                }
            }

        case .hydration:
            if let waterIntake = log.waterIntake, waterIntake > 0 {
                return hydrationColor(ounces: waterIntake)
            }
            
        case .meals:
            if viewModel.hasMeals(for: log.date) {
                return Theme.shared.accent.opacity(0.75)
            }
            
        case .activities:
            if viewModel.hasActivities(for: log.date) {
                return Theme.shared.accent.opacity(0.75)
            }
            
        case .medications:
            if medicationCount(in: log) > 0 {
                return Theme.shared.accent.opacity(0.75)
            }

        case .bowelMovements:
            // This category is colored using the separately stored movement records
            // in getCalendarRecords().
            break
            
        case .symptom(let id, _):
            if let rating = log.symptomRatings.first(where: { $0.symptomId == id }) {
                // Check if this is a binary symptom
                if let symptom = viewModel.trackedSymptoms.first(where: { $0.id == id }), symptom.isBinary {
                    // Binary symptom: simple yes/no coloring
                    if rating.rating > 0 {
                        // Present/Yes: Bold scarlet red
                        return Color(red: 0.92, green: 0.22, blue: 0.22).opacity(0.9)
                    } else {
                        // Absent/No: Fresh spring green
                        return Color(red: 0.35, green: 0.85, blue: 0.5).opacity(0.7)
                    }
                } else {
                    // Non-binary symptom: full gradient
                    switch rating.rating {
                        // Severe symptom: Bold scarlet red
                    case 8...10: return Color(red: 0.92, green: 0.22, blue: 0.22).opacity(0.92)
                        // Moderate symptom: Warm tangerine
                    case 5...7: return Color(red: 1.0, green: 0.6, blue: 0.25).opacity(0.88)
                        // Mild symptom: Gentle gold
                    case 3...4: return Color(red: 1.0, green: 0.85, blue: 0.35).opacity(0.75)
                        // Minimal symptom: Seafoam teal
                    case 1...2: return Color(red: 0.3, green: 0.78, blue: 0.7).opacity(0.7)
                        // No symptom: Fresh spring green
                    case 0: return Color(red: 0.35, green: 0.85, blue: 0.5).opacity(0.65)
                    default: return .gray.opacity(0.5)
                    }
                }
            }
        }
        
        return .clear
    }

    private func hydrationColor(ounces: Int) -> Color {
        guard hydrationGoalEnabled else { return CloveColors.blue.opacity(0.85) }
        let progress = Double(ounces) / Double(max(1, hydrationGoalOunces))
        switch progress {
        case ..<0.25: return CloveColors.red.opacity(0.85)
        case ..<0.50: return CloveColors.orange.opacity(0.85)
        case ..<0.75: return CloveColors.yellow.opacity(0.85)
        case ..<1.0: return CloveColors.blue.opacity(0.8)
        default: return CloveColors.green.opacity(0.9)
        }
    }

    private func bowelMovementColor(for movements: [BowelMovement]) -> Color {
        guard !movements.isEmpty else { return .clear }

        // Score each entry by its distance from the typical Bristol range (types 3–4).
        // Averaging individual distances avoids making a type 1 + type 7 day look
        // deceptively healthy simply because their numeric average is type 4.
        let averageDistance = movements.map { movement -> Double in
            let type = min(7.0, max(1.0, movement.type))
            if type < 3 { return 3 - type }
            if type > 4 { return type - 4 }
            return 0
        }.reduce(0, +) / Double(movements.count)

        switch averageDistance {
        case ...0.25: return CloveColors.green.opacity(0.9)
        case ...1.25: return CloveColors.yellow.opacity(0.85)
        case ...2.25: return CloveColors.orange.opacity(0.88)
        default: return CloveColors.red.opacity(0.9)
        }
    }
}

private struct MonthSnapshotCard: View {
    let title: String
    let daysRecorded: Int
    let flareDays: Int
    let cycleDays: Int
    let metricSummary: String?

    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            HStack {
                Label("\(title) snapshot", systemImage: "calendar.badge.clock")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(CloveColors.primaryText)
                Spacer()
            }

            HStack(spacing: 6) {
                snapshotPill("\(daysRecorded) day\(daysRecorded == 1 ? "" : "s") recorded", icon: "checkmark.circle")
                if flareDays > 0 {
                    snapshotPill("\(flareDays) flare\(flareDays == 1 ? "" : "s")", icon: "exclamationmark.triangle")
                }
                if cycleDays > 0 {
                    snapshotPill("\(cycleDays) period day\(cycleDays == 1 ? "" : "s")", icon: "drop")
                }
            }

            if let metricSummary {
                Text(metricSummary)
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
            }
        }
        .padding(CloveSpacing.medium)
        .background(RoundedRectangle(cornerRadius: CloveCorners.medium).fill(CloveColors.card))
    }

    private func snapshotPill(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(.caption2, design: .rounded, weight: .medium))
            .foregroundStyle(CloveColors.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(CloveColors.background.opacity(0.65)))
    }
}

private struct HistoryPreviewMetric: Identifiable {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var id: String { title }
}

private struct HistoryDayPreviewCard: View {
    let date: Date
    let hasData: Bool
    let metrics: [HistoryPreviewMetric]
    let details: [String]
    let note: String?
    let cycleDescription: String?
    let onView: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(date.formatted(.dateTime.weekday(.wide)))
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                    Text(date.formatted(.dateTime.month(.wide).day()))
                        .font(CloveFonts.sectionTitle())
                        .fontWeight(.semibold)
                        .foregroundStyle(CloveColors.primaryText)
                }
                Spacer()
                if hasData {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.shared.accent)
                        .accessibilityLabel("Data recorded")
                }
            }

            if hasData {
                if !metrics.isEmpty {
                    HStack(spacing: CloveSpacing.small) {
                        ForEach(metrics) { metric in
                            metricTile(metric)
                        }
                    }
                }

                if let cycleDescription {
                    Label(cycleDescription, systemImage: "drop.fill")
                        .font(CloveFonts.small())
                        .foregroundStyle(.pink)
                }

                if !details.isEmpty {
                    Text(details.joined(separator: "  ·  "))
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let note = cleanedNote {
                    HStack(alignment: .top, spacing: CloveSpacing.small) {
                        Image(systemName: "quote.opening")
                            .font(.caption)
                            .foregroundStyle(Theme.shared.accent)
                        Text(note)
                            .font(CloveFonts.small())
                            .foregroundStyle(CloveColors.secondaryText)
                            .lineLimit(2)
                    }
                    .padding(CloveSpacing.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: CloveCorners.small).fill(CloveColors.background.opacity(0.55)))
                }

                HStack(spacing: CloveSpacing.small) {
                    Button("View full day", action: onView)
                        .historyActionStyle(isPrimary: false)
                    Button("Edit", action: onEdit)
                        .historyActionStyle(isPrimary: true)
                }
            } else {
                HStack(spacing: CloveSpacing.medium) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.shared.accent)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Theme.shared.accent.opacity(0.1)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nothing recorded")
                            .font(CloveFonts.body())
                            .fontWeight(.semibold)
                            .foregroundStyle(CloveColors.primaryText)
                        Text("You can add to this day whenever you need to.")
                            .font(CloveFonts.small())
                            .foregroundStyle(CloveColors.secondaryText)
                    }
                }

                Button("Add to this day", action: onEdit)
                    .historyActionStyle(isPrimary: true)
            }
        }
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.large)
                .fill(CloveColors.card)
                .overlay {
                    RoundedRectangle(cornerRadius: CloveCorners.large)
                        .stroke(Theme.shared.accent.opacity(0.14), lineWidth: 1)
                }
        )
    }

    private var cleanedNote: String? {
        guard let note else { return nil }
        let cleaned = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func metricTile(_ metric: HistoryPreviewMetric) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: metric.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(metric.value)
                    .font(.system(.headline, design: .rounded, weight: .bold))
            }
            .foregroundStyle(metric.color)
            Text(metric.title)
                .font(.caption2)
                .foregroundStyle(CloveColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CloveSpacing.small)
        .background(RoundedRectangle(cornerRadius: CloveCorners.small).fill(metric.color.opacity(0.1)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(metric.title), \(metric.value) out of 10")
    }
}

private extension View {
    func historyActionStyle(isPrimary: Bool) -> some View {
        self
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(isPrimary ? Color.white : Theme.shared.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .fill(isPrimary ? Theme.shared.accent : Theme.shared.accent.opacity(0.1))
            )
    }
}

struct ColorLegendView: View {
    let category: TrackingCategory
    let trackedSymptoms: [TrackedSymptom]
    let hydrationGoalOunces: Int
    let hydrationGoalEnabled: Bool
    let hydrationUnit: HydrationUnit
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Legend")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            switch category {
            case .mood:
                GradientLegendView(
                    colors: [
                        Color(red: 0.85, green: 0.25, blue: 0.35).opacity(0.9),
                        Color(red: 0.95, green: 0.5, blue: 0.3).opacity(0.85),
                        Color(red: 1.0, green: 0.75, blue: 0.3).opacity(0.8),
                        Color(red: 0.3, green: 0.72, blue: 0.65).opacity(0.85),
                        Color(red: 0.2, green: 0.78, blue: 0.55).opacity(0.9)
                    ],
                    labels: ["Worst", "Best"]
                )
                
            case .pain:
                GradientLegendView(
                    colors: [
                        Color(red: 0.35, green: 0.75, blue: 0.85).opacity(0.65),
                        Color(red: 0.4, green: 0.85, blue: 0.65).opacity(0.7),
                        Color(red: 1.0, green: 0.8, blue: 0.4).opacity(0.75),
                        Color(red: 0.95, green: 0.52, blue: 0.2).opacity(0.88),
                        Color(red: 0.9, green: 0.2, blue: 0.25).opacity(0.92)
                    ],
                    labels: ["None", "Severe"]
                )
                
            case .energy:
                GradientLegendView(
                    colors: [
                        Color(red: 0.35, green: 0.35, blue: 0.55).opacity(0.85),
                        Color(red: 0.5, green: 0.5, blue: 0.7).opacity(0.7),
                        Color(red: 0.65, green: 0.6, blue: 0.85).opacity(0.75),
                        Color(red: 0.25, green: 0.7, blue: 0.95).opacity(0.85),
                        Color(red: 1.0, green: 0.85, blue: 0.2).opacity(0.9)
                    ],
                    labels: ["Exhausted", "Energized"]
                )

            case .hydration:
                if hydrationGoalEnabled {
                    GradientLegendView(
                        colors: [
                            CloveColors.red.opacity(0.85),
                            CloveColors.orange.opacity(0.85),
                            CloveColors.yellow.opacity(0.85),
                            CloveColors.blue.opacity(0.8),
                            CloveColors.green.opacity(0.9)
                        ],
                        labels: ["Low", "Goal met (\(hydrationUnit.formatted(canonicalOunces: hydrationGoalOunces)))"]
                    )
                } else {
                    BinaryLegendView(
                        noColor: .clear,
                        yesColor: CloveColors.blue.opacity(0.85),
                        noLabel: "None",
                        yesLabel: "Logged"
                    )
                }
                
            case .meals:
                BinaryLegendView(
                    noColor: .clear,
                    yesColor: Theme.shared.accent.opacity(0.75),
                    noLabel: "None",
                    yesLabel: "Logged"
                )
                
            case .activities:
                BinaryLegendView(
                    noColor: .clear,
                    yesColor: Theme.shared.accent.opacity(0.75),
                    noLabel: "None",
                    yesLabel: "Logged"
                )
                
            case .medications:
                BinaryLegendView(
                    noColor: .clear,
                    yesColor: Theme.shared.accent.opacity(0.75),
                    noLabel: "None",
                    yesLabel: "Logged"
                )

            case .bowelMovements:
                GradientLegendView(
                    colors: [
                        CloveColors.red.opacity(0.9),
                        CloveColors.orange.opacity(0.88),
                        CloveColors.yellow.opacity(0.85),
                        CloveColors.green.opacity(0.9)
                    ],
                    labels: ["Far from typical", "Types 3–4"]
                )
                
            case .symptom(let id, _):
                // Check if binary symptom
                if let symptom = trackedSymptoms.first(where: { $0.id == id }), symptom.isBinary {
                    BinaryLegendView(
                        noColor: Color(red: 0.35, green: 0.85, blue: 0.5).opacity(0.7),
                        yesColor: Color(red: 0.92, green: 0.22, blue: 0.22).opacity(0.9),
                        noLabel: "Absent",
                        yesLabel: "Present"
                    )
                } else {
                    GradientLegendView(
                        colors: [
                            Color(red: 0.35, green: 0.85, blue: 0.5).opacity(0.65),
                            Color(red: 0.3, green: 0.78, blue: 0.7).opacity(0.7),
                            Color(red: 1.0, green: 0.85, blue: 0.35).opacity(0.75),
                            Color(red: 1.0, green: 0.6, blue: 0.25).opacity(0.88),
                            Color(red: 0.92, green: 0.22, blue: 0.22).opacity(0.92)
                        ],
                        labels: ["None", "Severe"]
                    )
                }
                
            case .allData:
                EmptyView()
            }
        }
    }
}

struct GradientLegendView: View {
    let colors: [Color]
    let labels: [String]
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(0..<colors.count, id: \.self) { index in
                    Rectangle()
                        .fill(colors[index])
                        .frame(height: 20)
                        .cornerRadius(index == 0 ? 4 : 0, corners: [.topLeft, .bottomLeft])
                        .cornerRadius(index == colors.count - 1 ? 4 : 0, corners: [.topRight, .bottomRight])
                }
            }
            .frame(maxWidth: 300)
            
            HStack {
                Text(labels[0])
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(labels[1])
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 300)
        }
    }
}

struct BinaryLegendView: View {
    let noColor: Color
    let yesColor: Color
    let noLabel: String
    let yesLabel: String
    
    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(noColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: noColor == .clear ? 1 : 0)
                    )
                    .frame(width: 24, height: 20)
                Text(noLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(yesColor)
                    .frame(width: 24, height: 20)
                Text(yesLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// Helper extension for corner radius on specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct EmptyLogView: View {
    let date: Date
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                
                Text(formattedDate)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("No log recorded for this day")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    createLogForDay()
                }) {
                    Text("Create Log")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.shared.accent)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                
                Button("Dismiss") {
                    dismiss()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .presentationDetents([.medium])
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
    
    private func createLogForDay() {
        // Navigate to Today tab and set the date for editing
        NavigationCoordinator.shared.editDayInTodayView(date: date)
        
        // Dismiss this view
        dismiss()
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

#Preview("With Data") {
    NavigationView {
        HistoryCalendarView()
    }
    .previewScenario(.withData(days: 30))
}

#Preview("Empty") {
    NavigationView {
        HistoryCalendarView()
    }
    .previewScenario(.empty)
}
