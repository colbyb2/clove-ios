import SwiftUI

struct TodayView: View {
    @State var viewModel = TodayViewModel()
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
    @AppStorage(Constants.FOCUSED_CHECK_IN) private var focusedCheckIn = false
    @State private var layoutPreferences = TodayLayoutPreferences.load()

    @State private var showEditSymptoms: Bool = false
    @State private var showQuickAddSymptomSheet: Bool = false
    @State private var showWeatherSelection: Bool = false
    @State private var showMedicationSelection: Bool = false
    @State private var showNotesEntry: Bool = false
    @State private var showCycleEntry: Bool = false
    @State private var cycleEntryPreset: CycleEntryPreset?

    var body: some View {
        ZStack {
            CloveColors.background
                .edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Date Navigation Header
                    DateNavigationHeader(
                        selectedDate: $viewModel.selectedDate,
                        isFocused: focusedCheckIn,
                        onToggleFocus: {
                            withAnimation(.easeInOut(duration: 0.2)) { focusedCheckIn.toggle() }
                        },
                        onDateChange: { newDate in self.viewModel.loadLogData(for: newDate) }
                    )

                    if let error = viewModel.loadError {
                        RepositoryErrorView(error: error, onRetry: viewModel.retryLoad)
                    }

                    if viewModel.hasLoadedData {
                    // Yesterday's Summary stays out of the way during a focused check-in.
                    if !focusedCheckIn, viewModel.yesterdayLog != nil
                        && Calendar.current.isDateInToday(viewModel.selectedDate)
                    {
                        YesterdaySummary(
                            yesterdayLog: viewModel.yesterdayLog,
                            settings: viewModel.settings
                        )
                    }

                    ForEach(visibleModules) { module in
                        moduleContainer(module)
                    }

                    if visibleModules.isEmpty {
                        VStack(spacing: CloveSpacing.small) {
                            Image(systemName: focusedCheckIn ? "scope" : "rectangle.3.group")
                                .font(.title2)
                                .foregroundStyle(Theme.shared.accent)
                            Text(focusedCheckIn ? "No essentials are enabled" : "No Today modules are visible")
                                .font(.headline)
                            Text(focusedCheckIn
                                 ? "Mark enabled modules as Essential in Arrange Today, or return to the full check-in."
                                 : "You can restore modules from Settings → Tracking & Logging → Arrange Today.")
                                .font(.caption)
                                .foregroundStyle(CloveColors.secondaryText)
                                .multilineTextAlignment(.center)
                            if focusedCheckIn {
                                Button("Show all modules") { focusedCheckIn = false }
                                    .buttonStyle(.bordered)
                                    .tint(Theme.shared.accent)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(CloveSpacing.large)
                        .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.medium))
                    }

                    } else if viewModel.loadError == nil {
                        ProgressView("Loading your health data...")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                    }

                }
                .padding()
            }
            .padding(.vertical)
            .overlay(alignment: .bottom) {
                if viewModel.hasLoadedData, viewModel.saveState != .saved {
                    DailySaveStatusView(
                        state: viewModel.saveState,
                        onRetry: viewModel.retrySave
                    )
                    .padding(.horizontal, CloveSpacing.medium)
                    .padding(.bottom, CloveSpacing.small)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(viewModel.saveState == .failed)
                    .zIndex(10)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.saveState)
        }
        .onAppear {
            layoutPreferences = .load()
            viewModel.load()
            if TutorialManager.shared.startTutorial(Tutorials.TodayView) == .Failure {
                print("Tutorial [TodayView] Failed to Start")
            }
        }
        .onDisappear {
            viewModel.flushPendingChanges(showFailureFeedback: true)
        }
        .onChange(of: navigationCoordinator.targetDate) { _, newDate in
            if let targetDate = newDate {
                viewModel.loadLogData(for: targetDate)
                navigationCoordinator.clearTargetDate()
            }
        }
        .onChange(of: viewModel.logData.mood) { _, _ in viewModel.scheduleAutoSave(for: .mood) }
        .onChange(of: viewModel.logData.painLevel) { _, _ in viewModel.scheduleAutoSave(for: .painLevel) }
        .onChange(of: viewModel.logData.energyLevel) { _, _ in viewModel.scheduleAutoSave(for: .energyLevel) }
        .onChange(of: viewModel.logData.isFlareDay) { _, _ in viewModel.scheduleAutoSave(for: .isFlareDay) }
        .onChange(of: viewModel.logData.weather) { _, _ in viewModel.scheduleAutoSave(for: .weather) }
        .onChange(of: viewModel.logData.notes) { _, _ in viewModel.scheduleAutoSave(for: .notes) }
        .onChange(of: viewModel.logData.medicationAdherence) { _, _ in viewModel.scheduleAutoSave(for: .medicationAdherence) }
        .onChange(of: viewModel.logData.symptomRatings) { _, _ in viewModel.scheduleAutoSave(for: .symptomRatings) }
        .sheet(isPresented: $showEditSymptoms) {
            EditSymptomsSheet(
                trackedSymptoms: viewModel.trackedSymptoms,
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
        .sheet(isPresented: $showCycleEntry) {
            CycleEntrySheet(
                date: viewModel.selectedDate,
                existingEntry: viewModel.cycleEntry,
                preset: cycleEntryPreset
            ) {
                viewModel.loadCycleEntry(for: viewModel.selectedDate)
                cycleEntryPreset = nil
            }
            .onDisappear { cycleEntryPreset = nil }
        }
    }

    private var visibleModules: [TodayModule] {
        layoutPreferences.order.filter { module in
            moduleIsEnabled(module)
                && !layoutPreferences.hidden.contains(module)
                && (!focusedCheckIn || layoutPreferences.essentials.contains(module))
        }
    }

    @ViewBuilder
    private func moduleContainer(_ module: TodayModule) -> some View {
        if layoutPreferences.collapsed.contains(module) {
            Button {
                layoutPreferences.collapsed.remove(module)
                layoutPreferences.save()
            } label: {
                HStack(spacing: CloveSpacing.small) {
                    Image(systemName: module.icon)
                        .foregroundStyle(Theme.shared.accent)
                        .frame(width: 30)
                    Text(module.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CloveColors.primaryText)
                    Spacer()
                    if needsEntry(module) == true {
                        Text("Needs entry")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(CloveColors.secondaryText)
                }
                .padding(CloveSpacing.medium)
                .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.medium))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Expands \(module.title)")
        } else {
            VStack(alignment: .leading, spacing: 6) {
                if focusedCheckIn, needsEntry(module) == true {
                    Label("Not answered yet", systemImage: "circle.dashed")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
                moduleContent(module)
            }
        }
    }

    @ViewBuilder
    private func moduleContent(_ module: TodayModule) -> some View {
        switch module {
        case .mood:
            AccessibleRatingInput(value: $viewModel.logData.mood, label: "Mood", icon: viewModel.currentMoodSymbol, maxValue: 10)
        case .pain:
            AccessibleRatingInput(value: $viewModel.logData.painLevel, label: "Pain Level", icon: CloveSymbols.pain, maxValue: 10)
        case .energy:
            AccessibleRatingInput(value: $viewModel.logData.energyLevel, label: "Energy Level", icon: CloveSymbols.energy, maxValue: 10)
        case .hydration:
            HydrationTracker(ounces: $viewModel.logData.waterIntake) { _ in viewModel.saveHydration() }
        case .symptoms:
            symptomsSection
        case .meals:
            FoodTracker(date: viewModel.selectedDate)
        case .activities:
            ActivityTracker(date: viewModel.selectedDate)
        case .medications:
            medicationsModule
        case .weather:
            weatherModule
        case .bowelMovements:
            BowelMovementTracker(date: viewModel.selectedDate)
        case .cycle:
            TodayCycleCard(
                date: viewModel.selectedDate,
                entry: viewModel.cycleEntry,
                cycleDay: viewModel.currentCycleDay,
                isPeriodActive: viewModel.isPeriodActive,
                onLog: { preset in
                    cycleEntryPreset = preset
                    showCycleEntry = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                },
                onDelete: viewModel.deleteCycleEntry,
                onHide: { hideModule(.cycle) }
            )
        case .notes:
            notesModule
        case .flare:
            flareModule
        }
    }

    private var medicationsModule: some View {
        HStack {
            Label("Medications", systemImage: CloveSymbols.medication)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(CloveColors.primaryText)
            Spacer()
            Button {
                showMedicationSelection = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack {
                    Text(medicationSummaryText())
                    if viewModel.logData.medicationAdherence.isEmpty { Image(systemName: "plus.circle.fill") }
                }
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(viewModel.logData.medicationAdherence.isEmpty ? CloveColors.secondaryText : CloveColors.primary)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.small))
                .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
            }
            .accessibilityLabel("Medication tracking")
            .accessibilityHint("Opens medication checklist")
        }
        .padding(.vertical, CloveSpacing.small)
    }

    private var weatherModule: some View {
        HStack {
            Label("Weather", systemImage: CloveSymbols.weather(for: viewModel.logData.weather))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(CloveColors.primaryText)
            Spacer()
            Button {
                showWeatherSelection = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack {
                    Text(viewModel.logData.weather ?? "Tap to select")
                    if viewModel.logData.weather == nil { Image(systemName: "plus.circle.fill") }
                }
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(viewModel.logData.weather == nil ? CloveColors.secondaryText : CloveColors.primary)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.small))
                .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
            }
            .accessibilityLabel("Weather selection")
            .accessibilityHint("Opens weather selection dialog")
        }
        .padding(.vertical, CloveSpacing.small)
    }

    private var notesModule: some View {
        HStack {
            Label("Notes", systemImage: CloveSymbols.notes)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(CloveColors.primaryText)
            Spacer()
            Button {
                showNotesEntry = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack {
                    Text(notesSummaryText()).lineLimit(1)
                    if viewModel.logData.notes == nil { Image(systemName: "plus.circle.fill") }
                }
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(viewModel.logData.notes == nil ? CloveColors.secondaryText : CloveColors.primary)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.small))
                .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
            }
            .accessibilityLabel("Notes entry")
            .accessibilityHint("Opens notes editor for this day")
        }
        .padding(.vertical, CloveSpacing.small)
    }

    private var flareModule: some View {
        VStack(spacing: CloveSpacing.small) {
            HStack {
                Label("Flare Day", systemImage: CloveSymbols.flare)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(CloveColors.primaryText)
                Spacer()
                CloveToggle(toggled: $viewModel.logData.isFlareDay, onColor: .error, handleColor: .card.opacity(0.6))
                    .accessibilityLabel("Flare day toggle")
                    .onChange(of: viewModel.logData.isFlareDay) { _, _ in
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
            }
            if viewModel.logData.isFlareDay {
                Text("Take care of yourself today")
                    .font(CloveFonts.small()).foregroundStyle(CloveColors.secondaryText).italic()
            }
        }
        .padding(.vertical, CloveSpacing.small)
    }

    private func moduleIsEnabled(_ module: TodayModule) -> Bool {
        switch module {
        case .mood: viewModel.settings.trackMood
        case .pain: viewModel.settings.trackPain
        case .energy: viewModel.settings.trackEnergy
        case .hydration: viewModel.settings.trackHydration
        case .symptoms: viewModel.settings.trackSymptoms
        case .meals: viewModel.settings.trackMeals
        case .activities: viewModel.settings.trackActivities
        case .medications: viewModel.settings.trackMeds
        case .weather: viewModel.settings.trackWeather
        case .bowelMovements: viewModel.settings.trackBowelMovements
        case .cycle: viewModel.settings.trackCycle
        case .notes: viewModel.settings.trackNotes
        case .flare: viewModel.settings.showFlareToggle
        }
    }

    private func needsEntry(_ module: TodayModule) -> Bool? {
        switch module {
        case .mood: viewModel.logData.mood == nil
        case .pain: viewModel.logData.painLevel == nil
        case .energy: viewModel.logData.energyLevel == nil
        case .hydration: viewModel.logData.waterIntake == 0
        case .symptoms: viewModel.logData.symptomRatings.contains { $0.ratingDouble == nil }
        case .medications: viewModel.logData.medicationAdherence.isEmpty
        case .weather: viewModel.logData.weather == nil
        case .bowelMovements: viewModel.logData.bowelMovements.isEmpty
        case .cycle: viewModel.cycleEntry == nil
        case .notes: viewModel.logData.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
        case .meals, .activities, .flare: nil
        }
    }

    private func hideModule(_ module: TodayModule) {
        withAnimation(.easeInOut(duration: 0.2)) {
            layoutPreferences.hidden.insert(module)
            layoutPreferences.save()
        }
    }

    @ViewBuilder
    private var symptomsSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Symptoms").font(.system(size: 22, weight: .semibold, design: .rounded))
                Text("Unanswered symptoms are not included in your data")
                    .font(.caption)
                    .foregroundStyle(CloveColors.secondaryText)
            }
            Spacer()
            Button("Manage") {
                showEditSymptoms = true
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
            .foregroundStyle(Theme.shared.accent)
            .fontWeight(.semibold)
            .frame(minWidth: 44, minHeight: 44)  // Minimum touch target
            .accessibilityLabel("Manage tracked symptoms")
            .accessibilityHint("Choose which symptoms appear in the daily tracker")
        }
        ForEach(viewModel.logData.symptomRatings, id: \.symptomId) { symptomRating in
            if let index = viewModel.logData.symptomRatings.firstIndex(where: {
                $0.symptomId == symptomRating.symptomId
            }) {
                let isOneTimeSymptom = SymptomManager.shared.isOneTimeSymptom(
                    id: symptomRating.symptomId, name: symptomRating.symptomName)

                if isOneTimeSymptom {
                    HStack(spacing: 8) {
                        Text("Today only")
                            .font(.caption2.bold())
                            .foregroundStyle(Theme.shared.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.shared.accent.opacity(0.12), in: Capsule())
                        Text(viewModel.selectedDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(CloveColors.secondaryText)
                        Spacer()
                        Button("Track every day") { promoteOneTimeSymptom(at: index) }
                            .font(.caption.bold())
                            .foregroundStyle(Theme.shared.accent)
                    }
                }

                if symptomRating.isBinary {
                    BinarySymptomInput(
                        value: $viewModel.logData.symptomRatings[index].ratingDouble,
                        label: symptomRating.symptomName,
                        icon: CloveSymbols.symptom,
                        onDelete: isOneTimeSymptom
                            ? { viewModel.logData.symptomRatings.remove(at: index) } : nil
                    )
                } else {
                    AccessibleRatingInput(
                        value: $viewModel.logData.symptomRatings[index].ratingDouble,
                        label: symptomRating.symptomName,
                        icon: CloveSymbols.symptom,
                        maxValue: 10,
                        onDelete: isOneTimeSymptom
                            ? { viewModel.logData.symptomRatings.remove(at: index) } : nil
                    )
                }
            }
        }
        if viewModel.logData.symptomRatings.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "stethoscope")
                    .font(.title2)
                    .foregroundStyle(Theme.shared.accent)
                Text("No symptoms tracked daily")
                    .font(.headline)
                Text("Choose symptoms you regularly monitor, or log something just for this day.")
                    .font(.caption)
                    .foregroundStyle(CloveColors.secondaryText)
                    .multilineTextAlignment(.center)
                Button("Choose tracked symptoms") { showEditSymptoms = true }
                    .buttonStyle(.bordered)
                    .tint(Theme.shared.accent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }

        // Quick add button for occasional symptoms
        Button(action: {
            showQuickAddSymptomSheet = true
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Log another symptom today")
                        .foregroundStyle(CloveColors.primaryText)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text("Only appears on \(viewModel.selectedDate.formatted(date: .abbreviated, time: .omitted))")
                        .foregroundStyle(CloveColors.secondaryText)
                        .font(.caption2)
                }

                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Theme.shared.accent)
                    .font(.system(size: 14))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
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

    private func promoteOneTimeSymptom(at index: Int) {
        guard viewModel.logData.symptomRatings.indices.contains(index) else { return }
        let rating = viewModel.logData.symptomRatings[index]
        if let existing = viewModel.trackedSymptoms.first(where: {
            $0.name.caseInsensitiveCompare(rating.symptomName) == .orderedSame
        }), let id = existing.id {
            viewModel.logData.symptomRatings[index].symptomId = id
            return
        }
        let originalID = rating.symptomId
        SymptomManager.shared.addSymptom(name: rating.symptomName, isBinary: rating.isBinary) {
            viewModel.loadTrackedSymptoms()
            guard let id = viewModel.trackedSymptoms.first(where: {
                $0.name.caseInsensitiveCompare(rating.symptomName) == .orderedSame
            })?.id,
            let currentIndex = viewModel.logData.symptomRatings.firstIndex(where: { $0.symptomId == originalID }) else { return }
            viewModel.logData.symptomRatings[currentIndex].symptomId = id
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

private struct DailySaveStatusView: View {
    let state: TodayViewModel.SaveState
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            statusIcon

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(statusColor)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(CloveColors.secondaryText)
            }

            Spacer()

            if state == .failed {
                Button("Retry", action: onRetry)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 38)
                    .background(CloveColors.error, in: Capsule())
            }
        }
        .padding(.horizontal, CloveSpacing.medium)
        .padding(.vertical, 12)
        .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.medium))
        .overlay {
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .stroke(statusColor.opacity(0.55), lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 4)
        .animation(.easeInOut(duration: 0.2), value: state)
        .accessibilityElement(children: state == .failed ? .contain : .combine)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if state == .saving {
            ProgressView()
                .tint(statusColor)
                .frame(width: 22, height: 22)
        } else {
            Image(systemName: state == .saved ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 22, height: 22)
        }
    }

    private var title: String {
        switch state {
        case .saved: "Saved"
        case .saving: "Saving changes..."
        case .failed: "Changes not saved"
        }
    }

    private var detail: String {
        switch state {
        case .saved: "Changes save automatically"
        case .saving: "You can keep tracking while this finishes"
        case .failed: "Your changes are still here. Try again."
        }
    }

    private var statusColor: Color {
        switch state {
        case .saved: CloveColors.success
        case .saving: Theme.shared.accent
        case .failed: CloveColors.error
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
