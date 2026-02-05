import SwiftUI

struct TodayView: View {
    @State var viewModel = TodayViewModel()
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
    
    @State private var showEditSymptoms: Bool = false
    @State private var showQuickAddSymptomSheet: Bool = false
    @State private var showWeatherSelection: Bool = false
    @State private var showMedicationSelection: Bool = false
    @State private var showNotesEntry: Bool = false
    @State private var showOccasionalFeaturesMenu: Bool = false
    @State private var showCycleEntry: Bool = false

    private var shouldShowQuickAdd: Bool {
        viewModel.settings.trackCycle
        // Future: || viewModel.settings.trackOtherFeature
    }

    var body: some View {
        ZStack {
            CloveColors.background
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Date Navigation Header
                    DateNavigationHeader(selectedDate: $viewModel.selectedDate) { newDate in
                        self.viewModel.loadLogData(for: newDate)
                    }
                    
                    // Yesterday's Summary (only show if data exists or it's helpful for context)
                    if (viewModel.yesterdayLog != nil && Calendar.current.isDateInToday(viewModel.selectedDate)) {
                        YesterdaySummary(
                            yesterdayLog: viewModel.yesterdayLog,
                            settings: viewModel.settings
                        )
                    }
                    
                    if viewModel.settings.trackMood {
                        AccessibleRatingInput(
                            value: $viewModel.logData.mood,
                            label: "Mood",
                            emoji: String(viewModel.currentMoodEmoji),
                            maxValue: 10
                        )
                    }
                    
                    if viewModel.settings.trackPain {
                        AccessibleRatingInput(
                            value: $viewModel.logData.painLevel,
                            label: "Pain Level",
                            emoji: "🩹",
                            maxValue: 10
                        )
                    }
                    
                    if viewModel.settings.trackEnergy {
                        AccessibleRatingInput(
                            value: $viewModel.logData.energyLevel,
                            label: "Energy Level",
                            emoji: "⚡",
                            maxValue: 10
                        )
                    }
                    
                    if viewModel.settings.trackSymptoms {
                        symptomsSection
                    }
                    
                    if viewModel.settings.trackMeals {
                        FoodTracker(date: viewModel.selectedDate)
                    }

                    if viewModel.settings.trackActivities {
                        ActivityTracker(date: viewModel.selectedDate)
                    }
                    
                    if viewModel.settings.trackMeds {
                        VStack(spacing: CloveSpacing.small) {
                            HStack {
                                HStack(spacing: CloveSpacing.small) {
                                    Text("💊")
                                        .font(.system(size: 20))
                                    Text("Medications")
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    showMedicationSelection = true
                                    // Haptic feedback
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }) {
                                    HStack {
                                        Text(medicationSummaryText())
                                            .foregroundStyle(viewModel.logData.medicationAdherence.isEmpty ? CloveColors.secondaryText : CloveColors.primary)
                                            .font(.system(.body, design: .rounded).weight(.medium))
                                        
                                        if viewModel.logData.medicationAdherence.isEmpty {
                                            Image(systemName: "plus.circle.fill")
                                                .foregroundStyle(Theme.shared.accent)
                                                .font(.system(size: 16))
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(CloveColors.card)
                                    .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
                                    .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
                                }
                                .accessibilityLabel("Medication tracking")
                                .accessibilityHint("Opens medication checklist")
                            }
                        }
                        .padding(.vertical, CloveSpacing.small)
                    }
                    
                    if viewModel.settings.trackWeather {
                        VStack(spacing: CloveSpacing.small) {
                            HStack {
                                HStack(spacing: CloveSpacing.small) {
                                    Text(weatherEmoji(for: viewModel.logData.weather))
                                        .font(.system(size: 20))
                                    Text("Weather")
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    showWeatherSelection = true
                                    // Haptic feedback
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }) {
                                    HStack {
                                        Text(viewModel.logData.weather ?? "Tap to select")
                                            .foregroundStyle(viewModel.logData.weather != nil ? CloveColors.primary : CloveColors.secondaryText)
                                            .font(.system(.body, design: .rounded).weight(.medium))
                                        
                                        if viewModel.logData.weather == nil {
                                            Image(systemName: "plus.circle.fill")
                                                .foregroundStyle(Theme.shared.accent)
                                                .font(.system(size: 16))
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(CloveColors.card)
                                    .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
                                    .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
                                }
                                .accessibilityLabel("Weather selection")
                                .accessibilityHint("Opens weather selection dialog")
                            }
                        }
                        .padding(.vertical, CloveSpacing.small)
                    }
                    
                    if viewModel.settings.trackBowelMovements {
                        BowelMovementTracker(date: viewModel.selectedDate)
                    }
                    
                    // MARK: Cycle Indicator
                    if let cycle = viewModel.cycleEntry {
                        VStack(spacing: CloveSpacing.small) {
                            HStack(spacing: CloveSpacing.small) {
                                Text("🩸")
                                    .font(.system(size: 20))
                                Text("Cycle")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))

                                Text("BETA")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color.pink)
                                    )

                                Spacer()
                            }
                            
                            CycleIndicator(
                                cycle: cycle,
                                onTap: {
                                    showCycleEntry = true
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                },
                                onDelete: {
                                    viewModel.deleteCycleEntry()
                                }
                            )
                        }
                        .padding(.vertical, CloveSpacing.small)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // MARK: Notes
                    if viewModel.settings.trackNotes {
                        VStack(spacing: CloveSpacing.small) {
                            HStack {
                                HStack(spacing: CloveSpacing.small) {
                                    Text("📝")
                                        .font(.system(size: 20))
                                    Text("Notes")
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    showNotesEntry = true
                                    // Haptic feedback
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }) {
                                    HStack {
                                        Text(notesSummaryText())
                                            .foregroundStyle(viewModel.logData.notes != nil ? CloveColors.primary : CloveColors.secondaryText)
                                            .font(.system(.body, design: .rounded).weight(.medium))
                                            .lineLimit(1)
                                        
                                        if viewModel.logData.notes == nil {
                                            Image(systemName: "plus.circle.fill")
                                                .foregroundStyle(Theme.shared.accent)
                                                .font(.system(size: 16))
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(CloveColors.card)
                                    .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
                                    .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
                                }
                                .accessibilityLabel("Notes entry")
                                .accessibilityHint("Opens notes editor for this day")
                            }
                        }
                        .padding(.vertical, CloveSpacing.small)
                    }
                    
                    // MARK: Flare Toggle
                    if viewModel.settings.showFlareToggle {
                        VStack(spacing: CloveSpacing.small) {
                            HStack {
                                HStack(spacing: CloveSpacing.small) {
                                    Text("🔥")
                                        .font(.system(size: 20))
                                    Text("Flare Day")
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                }

                                Spacer()

                                CloveToggle(toggled: $viewModel.logData.isFlareDay, onColor: .error, handleColor: .card.opacity(0.6))
                                    .accessibilityLabel("Flare day toggle")
                                    .accessibilityHint(viewModel.logData.isFlareDay ? "Currently marked as flare day, tap to unmark" : "Currently not marked as flare day, tap to mark")
                                    .onChange(of: viewModel.logData.isFlareDay) { _, _ in
                                        // Haptic feedback for toggle
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                        impactFeedback.impactOccurred()
                                    }
                            }

                            if viewModel.logData.isFlareDay {
                                Text("Take care of yourself today")
                                    .font(CloveFonts.small())
                                    .foregroundStyle(CloveColors.secondaryText)
                                    .italic()
                            }
                        }
                        .padding(.vertical, CloveSpacing.small)
                    }
                    
                    // MARK: Quick Add
                    if shouldShowQuickAdd {
                        Button {
                            self.showOccasionalFeaturesMenu = true
                        } label: {
                            HStack(spacing: CloveSpacing.small) {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Track Other")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46) // Large touch target
                        .background(
                            RoundedRectangle(cornerRadius: CloveCorners.medium)
                                .fill(CloveColors.card)
                                .shadow(color: Theme.shared.accent.opacity(0.3), radius: 4, x: 0, y: 2)
                        )
                    }

                    // MARK: Save Button
                    Button(action: {
                        // Haptic feedback for save action
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        viewModel.saveLog()
                        
                        // Success haptic feedback (will be triggered by toast in ViewModel)
                    })
                    {
                        HStack(spacing: CloveSpacing.small) {
                            if viewModel.isSaving {
                                ProgressView()
                                    .scaleEffect(0.9)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            
                            Text(viewModel.isSaving ? "Saving..." : "Save Log")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56) // Large touch target
                        .background(
                            RoundedRectangle(cornerRadius: CloveCorners.medium)
                                .fill(viewModel.isSaving ? CloveColors.secondaryText : Theme.shared.accent)
                                .shadow(color: Theme.shared.accent.opacity(0.3), radius: 4, x: 0, y: 2)
                        )
                    }
                    .disabled(viewModel.isSaving)
                    .accessibilityLabel(viewModel.isSaving ? "Saving health log" : "Save today's health log")
                    .accessibilityHint(viewModel.isSaving ? "Currently saving with weather data" : "Saves all current ratings and settings")
                }
                .padding()
            }
            .padding(.vertical)
        }
        .onAppear {
            viewModel.load()
            if TutorialManager.shared.startTutorial(Tutorials.TodayView) == .Failure {
                print("Tutorial [TodayView] Failed to Start")
            }
        }
        .onChange(of: navigationCoordinator.targetDate) { _, newDate in
            if let targetDate = newDate {
                viewModel.loadLogData(for: targetDate)
                navigationCoordinator.clearTargetDate()
            }
        }
        .sheet(isPresented: $showEditSymptoms) {
            EditSymptomsSheet(
                trackedSymptoms: SymptomsRepo.shared.getTrackedSymptoms(),
                refresh: viewModel.loadTrackedSymptoms
            )
        }
        .sheet(isPresented: $showWeatherSelection) {
            WeatherSelectionSheet(selectedWeather: $viewModel.logData.weather)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showMedicationSelection) {
            MedicationSelectionSheet(medicationAdherence: $viewModel.logData.medicationAdherence)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showNotesEntry) {
            NotesEntrySheet(
                notes: $viewModel.logData.notes,
                date: viewModel.selectedDate
            )
        }
        .sheet(isPresented: $showOccasionalFeaturesMenu) {
            OccasionalFeaturesMenu(settings: viewModel.settings) { feature in
                switch feature {
                case .cycle:
                    showOccasionalFeaturesMenu = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCycleEntry = true
                    }
                }
            }
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
            .presentationBackground(CloveColors.card)
        }
        .sheet(isPresented: $showCycleEntry) {
            CycleEntrySheet(
                date: viewModel.selectedDate,
                existingEntry: viewModel.cycleEntry
            ) {
                viewModel.loadCycleEntry(for: viewModel.selectedDate)
            }
        }
    }

    @ViewBuilder
    private var symptomsSection: some View {
        HStack {
            Text("Symptoms").font(.system(size: 22, weight: .semibold, design: .rounded))
            Spacer()
            Button("Edit") {
                showEditSymptoms = true
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
            .foregroundStyle(Theme.shared.accent)
            .fontWeight(.semibold)
            .frame(minWidth: 44, minHeight: 44) // Minimum touch target
            .accessibilityLabel("Edit symptoms")
            .accessibilityHint("Opens symptoms management screen")
        }
        ForEach(viewModel.logData.symptomRatings, id: \.symptomId) { symptomRating in
            if let index = viewModel.logData.symptomRatings.firstIndex(where: { $0.symptomId == symptomRating.symptomId }) {
                let isOneTimeSymptom = SymptomManager.shared.isOneTimeSymptom(id: symptomRating.symptomId, name: symptomRating.symptomName)
                
                if symptomRating.isBinary {
                    BinarySymptomInput(
                        value: $viewModel.logData.symptomRatings[index].ratingDouble,
                        label: symptomRating.symptomName,
                        emoji: "🩺",
                        onDelete: isOneTimeSymptom ? { viewModel.logData.symptomRatings.remove(at: index) } : nil
                    )
                } else {
                    AccessibleRatingInput(
                        value: $viewModel.logData.symptomRatings[index].ratingDouble,
                        label: symptomRating.symptomName,
                        emoji: "🩺",
                        maxValue: 10,
                        onDelete: isOneTimeSymptom ? { viewModel.logData.symptomRatings.remove(at: index) } : nil
                    )
                }
            }
        }
        if (viewModel.logData.symptomRatings.isEmpty) {
            HStack {
                Spacer()
                Text("No Symptoms Being Tracked")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CloveColors.secondaryText)
                Spacer()
            }
        }

        // Quick add button for occasional symptoms
        Button(action: {
            showQuickAddSymptomSheet = true
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }) {
            HStack {
                Text("Add Symptom")
                    .foregroundStyle(CloveColors.secondaryText)
                    .font(.system(size: 14, weight: .medium, design: .rounded))

                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Theme.shared.accent)
                    .font(.system(size: 14))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(CloveColors.card)
            .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
            .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
        }
        .padding(.top, CloveSpacing.small)
        .sheet(isPresented: $showQuickAddSymptomSheet) {
            QuickAddSymptomSheet()
                .environment(viewModel)
        }
    }

    private func weatherEmoji(for weather: String?) -> String {
        switch weather {
        case "Sunny": return "☀️"
        case "Cloudy": return "☁️"
        case "Rainy": return "🌧️"
        case "Stormy": return "⛈️"
        case "Snow": return "❄️"
        case "Gloomy": return "🌫️"
        default: return "🌤️"
        }
    }
    
    private func medicationSummaryText() -> String {
        let adherence = viewModel.logData.medicationAdherence
        if adherence.isEmpty {
            return "Tap to track"
        }
        
        let takenCount = adherence.filter { $0.wasTaken }.count
        let totalCount = adherence.count
        
        if takenCount == 0 {
            return "None taken yet"
        } else if takenCount == totalCount {
            return "All taken (\(totalCount))"
        } else {
            return "\(takenCount) of \(totalCount) taken"
        }
    }
    
    private func notesSummaryText() -> String {
        guard let notes = viewModel.logData.notes, !notes.isEmpty else {
            return "Tap to add notes"
        }
        
        // Show first 40 characters with ellipsis if longer
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedNotes.count <= 40 {
            return trimmedNotes
        } else {
            return String(trimmedNotes.prefix(40)) + "..."
        }
    }
}

#Preview("All Features") {
    NavigationStack {
        TodayView(viewModel: TodayViewModel.preview(settings: .allEnabled))
    }
    .environment(NavigationCoordinator.shared)
    .previewScenario(.full)
}

#Preview("Minimal Features") {
    NavigationStack {
        TodayView(viewModel: TodayViewModel.preview(settings: .minimal))
    }
    .environment(NavigationCoordinator.shared)
    .previewScenario(.minimal)
}
