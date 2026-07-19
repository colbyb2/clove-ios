import SwiftUI

struct HistoryCalendarView: View {
    @Environment(\.dependencies) private var dependencies
    @AppStorage(Constants.HYDRATION_GOAL_OUNCES) private var hydrationGoalOunces = 64
    @State private var viewModel = HistoryCalendarViewModel()
    @State private var currentMonth = Date()
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Horizontal scrollable category picker
            CategoryPickerView(
                categories: viewModel.availableCategories,
                selectedCategory: $viewModel.selectedCategory
            )
            .padding(.horizontal)
            
            CalendarView(
                records: getCalendarRecords(),
                onDaySelected: { date in
                    viewModel.selectedDate = date
                },
                selectedDate: $currentMonth
            )
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
            .padding()
            .padding(.vertical)
            .sheet(item: $viewModel.selectedDate) { date in
                if let log = viewModel.log(for: date) {
                    DailyLogDetailView(log: log)
                } else if !viewModel.bowelMovements(for: date).isEmpty {
                    // Bowel movements are stored separately from DailyLog. A date-only
                    // log lets the existing detail screen load and display those records.
                    DailyLogDetailView(log: DailyLog(date: date))
                } else {
                    EmptyLogView(date: date)
                }
            }
            
            // Color legend (only show when filtering)
            if viewModel.selectedCategory != .allData {
                ColorLegendView(
                    category: viewModel.selectedCategory,
                    trackedSymptoms: viewModel.trackedSymptoms,
                    hydrationGoalOunces: hydrationGoalOunces
                )
                    .padding(.horizontal)
                    .padding(.bottom)
            }
            
            Spacer()
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
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.shared.accent)
                }
            }
        }
        .onAppear {
            viewModel.loadData()
            if dependencies.tutorialManager.startTutorial(Tutorials.CalendarView) == .Failure {
                print("Tutorial [CalendarView] Failed to Start")
            }
        }
    }
    
    func getCalendarRecords() -> [Date: CalendarRecord] {
        // Get all unique dates from logs, cycles, and predictions
        var allDates = Set(viewModel.logsByDate.keys).union(Set(viewModel.cyclesByDate.keys))
        if viewModel.userSettings.trackBowelMovements {
            allDates.formUnion(viewModel.bowelMovementsByDate.keys)
        }
        
        // Add predicted cycle dates if prediction exists
        let predictedDates = getPredictedCycleDates()
        allDates = allDates.union(predictedDates)
        
        var records: [Date: CalendarRecord] = [:]
        for date in allDates {
            let log = viewModel.logsByDate[date]
            let isPredicted = predictedDates.contains(date)
            
            // Only show cycle indicator if the feature is enabled
            let hasCycle = viewModel.userSettings.trackCycle && viewModel.cyclesByDate[date] != nil
            
            // Get the color based on the log data (if it exists)
            // Don't show heatmap color for predicted dates
            let color: Color
            if isPredicted {
                color = .clear
            } else if viewModel.selectedCategory == .bowelMovements {
                color = bowelMovementColor(for: viewModel.bowelMovements(for: date))
            } else if let log {
                color = getLogColor(log: log)
            } else if viewModel.selectedCategory == .allData,
                      !viewModel.bowelMovements(for: date).isEmpty {
                color = Theme.shared.accent.opacity(0.7)
            } else {
                color = .clear
            }
            
            records[date] = CalendarRecord(
                color: color,
                icon: nil,
                hasCycleEntry: hasCycle,
                isPredictedCycle: isPredicted
            )
        }
        
        return records
    }
    
    /// Get the set of dates that are part of the predicted cycle
    private func getPredictedCycleDates() -> Set<Date> {
        guard let prediction = viewModel.cyclePrediction,
              viewModel.userSettings.trackCycle else {
            return []
        }
        
        
        let calendar = Calendar.current
        var dates: Set<Date> = []
        
        for dayOffset in 0..<prediction.length {
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
            if !log.meals.isEmpty {
                return Theme.shared.accent.opacity(0.75)
            }
            
        case .activities:
            if !log.activities.isEmpty {
                return Theme.shared.accent.opacity(0.75)
            }
            
        case .medications:
            if !log.medicationsTaken.isEmpty {
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
                    if rating.rating >= 5 {
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

struct ColorLegendView: View {
    let category: TrackingCategory
    let trackedSymptoms: [TrackedSymptom]
    let hydrationGoalOunces: Int
    
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
                GradientLegendView(
                    colors: [
                        CloveColors.red.opacity(0.85),
                        CloveColors.orange.opacity(0.85),
                        CloveColors.yellow.opacity(0.85),
                        CloveColors.blue.opacity(0.8),
                        CloveColors.green.opacity(0.9)
                    ],
                    labels: ["Low", "Goal met (\(hydrationGoalOunces) oz)"]
                )
                
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
