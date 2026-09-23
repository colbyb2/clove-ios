import SwiftUI

private enum TodaySurface: String {
    case checkIn
    case plans
}

struct TodayView: View {
    @State var viewModel = TodayViewModel()
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
    @AppStorage(Constants.FOCUSED_CHECK_IN) private var focusedCheckIn = false
    @AppStorage(Constants.PACING_PLANS_ENABLED) private var pacingPlansEnabled = false
    @State private var layoutPreferences = TodayLayoutPreferences.load()
    @State private var selectedSurface: TodaySurface = .checkIn
    @State private var unfinishedPlanCount = 0
    @State private var expandedRatingModule: TodayModule?
    @State private var expandedSymptomID: Int64?

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
                VStack(alignment: .leading, spacing: 16) {
                    VStack(spacing: 8) {
                        DateNavigationHeader(
                            selectedDate: $viewModel.selectedDate,
                            isFocused: selectedSurface == .checkIn ? focusedCheckIn : nil,
                            onToggleFocus: selectedSurface == .checkIn ? {
                                withAnimation(.easeInOut(duration: 0.2)) { focusedCheckIn.toggle() }
                            } : nil,
                            onDateChange: handleDateChange
                        )

                        if pacingPlansEnabled {
                            surfacePicker
                        }
                    }

                    if selectedSurface == .plans, pacingPlansEnabled {
                        PacingPlanTracker(date: viewModel.selectedDate) {
                            refreshPlanCount()
                        }
                        .padding(CloveSpacing.medium)
                        .background(
                            CloveColors.card,
                            in: RoundedRectangle(cornerRadius: CloveCorners.medium)
                        )
                    } else {
                        checkInContent
                    }
                }
                .padding()
            }
            .padding(.vertical)
            .overlay(alignment: .bottom) {
                if selectedSurface == .checkIn, viewModel.hasLoadedData, viewModel.saveState != .saved {
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
            refreshPlanCount()
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
                refreshPlanCount(for: targetDate)
                navigationCoordinator.clearTargetDate()
            }
        }
        .onChange(of: pacingPlansEnabled) { _, isEnabled in
            if !isEnabled { selectedSurface = .checkIn }
            refreshPlanCount()
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

    @ViewBuilder
    private var checkInContent: some View {
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

    private var surfacePicker: some View {
        HStack(spacing: 2) {
            surfaceButton(.checkIn, title: "Check-in", icon: "checkmark.circle")
            surfaceButton(.plans, title: "Plans", icon: "leaf", count: unfinishedPlanCount)
        }
        .padding(2)
        .background(CloveColors.card.opacity(0.7), in: Capsule())
        .overlay {
            Capsule().stroke(CloveColors.secondaryText.opacity(0.1), lineWidth: 1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Today view")
    }

    private func surfaceButton(
        _ surface: TodaySurface,
        title: String,
        icon: String,
        count: Int? = nil
    ) -> some View {
        let isSelected = selectedSurface == surface
        return Button {
            guard selectedSurface != surface else { return }
            withAnimation(.easeInOut(duration: 0.18)) { selectedSurface = surface }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 5)
                        .frame(minHeight: 17)
                        .background(Theme.shared.accent.opacity(isSelected ? 0.16 : 0.09), in: Capsule())
                }
            }
            .foregroundStyle(isSelected ? Theme.shared.accent : CloveColors.secondaryText)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(
                isSelected ? Theme.shared.accent.opacity(0.11) : Color.clear,
                in: Capsule()
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func handleDateChange(_ date: Date) {
        viewModel.loadLogData(for: date)
        refreshPlanCount(for: date)
    }

    private func refreshPlanCount(for date: Date? = nil) {
        unfinishedPlanCount = PacingPlanRepo.shared.unfinishedCount(for: date ?? viewModel.selectedDate)
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
            TodayRatingInput(
                value: $viewModel.logData.mood,
                label: "Mood",
                icon: viewModel.currentMoodSymbol,
                isExpanded: .constant(true),
                isProminent: true
            )
        case .pain:
            TodayRatingInput(
                value: $viewModel.logData.painLevel,
                label: "Pain",
                icon: CloveSymbols.pain,
                isExpanded: ratingModuleExpansion(for: .pain)
            )
        case .energy:
            TodayRatingInput(
                value: $viewModel.logData.energyLevel,
                label: "Energy",
                icon: CloveSymbols.energy,
                isExpanded: ratingModuleExpansion(for: .energy)
            )
        case .hydration:
            HydrationTracker(ounces: $viewModel.logData.waterIntake) { _ in viewModel.saveHydration() }
        case .symptoms:
            symptomsSection
        case .meals:
            FoodTracker(date: viewModel.selectedDate)
        case .plans:
            EmptyView()
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
        TodayActionRow(
            title: "Medications",
            icon: CloveSymbols.medication,
            summary: medicationSummaryText(),
            hasValue: !viewModel.logData.medicationAdherence.isEmpty
        ) {
            showMedicationSelection = true
        }
    }

    private var weatherModule: some View {
        TodayActionRow(
            title: "Weather",
            icon: CloveSymbols.weather(for: viewModel.logData.weather),
            summary: viewModel.logData.weather ?? "Not logged",
            hasValue: viewModel.logData.weather != nil
        ) {
            showWeatherSelection = true
        }
    }

    private var notesModule: some View {
        TodayActionRow(
            title: "Notes",
            icon: CloveSymbols.notes,
            summary: notesSummaryText(),
            hasValue: viewModel.logData.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        ) {
            showNotesEntry = true
        }
    }

    private var flareModule: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Label("Flare Day", systemImage: CloveSymbols.flare)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
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
        .padding(CloveSpacing.medium)
        .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.medium))
    }

    private func moduleIsEnabled(_ module: TodayModule) -> Bool {
        switch module {
        case .mood: viewModel.settings.trackMood
        case .pain: viewModel.settings.trackPain
        case .energy: viewModel.settings.trackEnergy
        case .hydration: viewModel.settings.trackHydration
        case .symptoms: viewModel.settings.trackSymptoms
        case .meals: viewModel.settings.trackMeals
        case .plans: false
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
        case .meals, .plans, .activities, .flare: nil
        }
    }

    private func hideModule(_ module: TodayModule) {
        withAnimation(.easeInOut(duration: 0.2)) {
            layoutPreferences.hidden.insert(module)
            layoutPreferences.save()
        }
    }

    private func ratingModuleExpansion(for module: TodayModule) -> Binding<Bool> {
        Binding(
            get: { expandedRatingModule == module },
            set: { isExpanded in
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedRatingModule = isExpanded ? module : nil
                }
            }
        )
    }

    private func symptomExpansion(for id: Int64) -> Binding<Bool> {
        Binding(
            get: { expandedSymptomID == id },
            set: { isExpanded in
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedSymptomID = isExpanded ? id : nil
                }
            }
        )
    }

    @ViewBuilder
    private var symptomsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: CloveSpacing.small) {
                Image(systemName: CloveSymbols.symptom)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.shared.accent)
                Text("Symptoms")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Spacer()
                Menu {
                    Button("Choose tracked symptoms", systemImage: "checklist") {
                        showEditSymptoms = true
                    }
                    Button("Log another symptom", systemImage: "plus") {
                        showQuickAddSymptomSheet = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(CloveColors.secondaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Symptom options")
            }

            ForEach(viewModel.logData.symptomRatings, id: \.symptomId) { symptomRating in
                if let index = viewModel.logData.symptomRatings.firstIndex(where: {
                    $0.symptomId == symptomRating.symptomId
                }) {
                    symptomRow(for: symptomRating, at: index)
                }
            }

            if viewModel.logData.symptomRatings.isEmpty {
                Button {
                    showEditSymptoms = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle")
                        Text("Choose symptoms to track")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.shared.accent)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }

            Button {
                showQuickAddSymptomSheet = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Label("Log another symptom", systemImage: "plus")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.shared.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(CloveSpacing.medium)
        .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.medium))
        .sheet(isPresented: $showQuickAddSymptomSheet) {
            QuickAddSymptomSheet()
                .environment(viewModel)
        }
    }

    @ViewBuilder
    private func symptomRow(for symptomRating: SymptomRatingVM, at index: Int) -> some View {
        let isOneTimeSymptom = SymptomManager.shared.isOneTimeSymptom(
            id: symptomRating.symptomId,
            name: symptomRating.symptomName
        )
        let deleteAction: (() -> Void)? = isOneTimeSymptom
            ? { viewModel.logData.symptomRatings.remove(at: index) }
            : nil

        VStack(alignment: .leading, spacing: 6) {
            if isOneTimeSymptom {
                HStack(spacing: 8) {
                    Text("Today only")
                        .font(.caption2.bold())
                        .foregroundStyle(Theme.shared.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.shared.accent.opacity(0.1), in: Capsule())
                    Spacer()
                    Button("Track every day") { promoteOneTimeSymptom(at: index) }
                        .font(.caption.bold())
                        .foregroundStyle(Theme.shared.accent)
                }
            }

            if symptomRating.isBinary {
                TodayBinarySymptomInput(
                    value: $viewModel.logData.symptomRatings[index].ratingDouble,
                    label: symptomRating.symptomName,
                    onDelete: deleteAction
                )
            } else {
                TodayRatingInput(
                    value: $viewModel.logData.symptomRatings[index].ratingDouble,
                    label: symptomRating.symptomName,
                    icon: nil,
                    isExpanded: symptomExpansion(for: symptomRating.symptomId),
                    isNested: true,
                    onDelete: deleteAction
                )
            }
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

private struct TodayActionRow: View {
    let title: String
    let icon: String
    let summary: String
    let hasValue: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.shared.accent)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(CloveColors.primaryText)
                Spacer(minLength: 10)
                Text(summary)
                    .font(.subheadline.weight(hasValue ? .semibold : .regular))
                    .foregroundStyle(hasValue ? CloveColors.primaryText : CloveColors.secondaryText)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(CloveColors.secondaryText)
            }
            .padding(CloveSpacing.medium)
            .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.medium))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(summary)")
        .accessibilityHint("Double tap to edit")
    }
}

private struct TodayRatingInput: View {
    @Binding var value: Double?
    let label: String
    let icon: String?
    @Binding var isExpanded: Bool
    var isProminent = false
    var isNested = false
    var onDelete: (() -> Void)?

    @AppStorage(Constants.USE_SLIDER_INPUT) private var useSliderInput = true

    init(
        value: Binding<Double?>,
        label: String,
        icon: String?,
        isExpanded: Binding<Bool>,
        isProminent: Bool = false,
        isNested: Bool = false,
        onDelete: (() -> Void)? = nil
    ) {
        self._value = value
        self.label = label
        self.icon = icon
        self._isExpanded = isExpanded
        self.isProminent = isProminent
        self.isNested = isNested
        self.onDelete = onDelete
    }

    private var showsEditor: Bool { isProminent || isExpanded }

    var body: some View {
        VStack(spacing: 10) {
            Button {
                guard !isProminent else { return }
                isExpanded.toggle()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 10) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.shared.accent)
                            .frame(width: 24)
                    }

                    Text(label)
                        .font(.system(size: isProminent ? 20 : 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(CloveColors.primaryText)

                    Spacer()

                    if let value {
                        Text("\(Int(value))")
                            .font(.system(size: isProminent ? 24 : 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.shared.accent)
                            .contentTransition(.numericText())
                    } else {
                        Text("Not logged")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(CloveColors.secondaryText)
                    }

                    if !isProminent {
                        Image(systemName: "chevron.down")
                            .font(.caption.bold())
                            .foregroundStyle(CloveColors.secondaryText)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(label), \(value.map { String(Int($0)) } ?? "not logged")")
            .accessibilityHint(isProminent ? "Rating control" : "Double tap to edit")

            if showsEditor {
                if value != nil {
                    HStack {
                        Button("Clear") { value = nil }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(CloveColors.secondaryText)
                        Spacer()
                        Button {
                            useSliderInput.toggle()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Label(
                                useSliderInput ? "Use buttons" : "Use slider",
                                systemImage: useSliderInput ? "plusminus" : "slider.horizontal.3"
                            )
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(CloveColors.secondaryText)
                        }
                    }
                }

                if value == nil || useSliderInput {
                    OptionalRatingSlider(value: $value, minValue: 0, maxValue: 10, step: 1)
                } else {
                    PlusMinusControls(value: answeredValue, minValue: 0, maxValue: 10, step: 1, label: label)
                }
            }
        }
        .padding(isNested ? 12 : CloveSpacing.medium)
        .background(
            isNested ? CloveColors.background.opacity(0.55) : CloveColors.card,
            in: RoundedRectangle(cornerRadius: isNested ? CloveCorners.small : CloveCorners.medium)
        )
        .overlay(alignment: .topTrailing) {
            if let onDelete {
                Menu {
                    Button("Remove", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption.bold())
                        .foregroundStyle(CloveColors.secondaryText)
                        .frame(width: 36, height: 36)
                }
                .padding(.trailing, 4)
                .accessibilityLabel("More options for \(label)")
            }
        }
    }

    private var answeredValue: Binding<Double> {
        Binding(
            get: { value ?? 5 },
            set: { value = $0 }
        )
    }
}

private struct OptionalRatingSlider: View {
    @Binding var value: Double?
    let minValue: Int
    let maxValue: Int
    let step: Int

    @State private var isDragging = false
    @State private var lastFeedbackValue: Double?

    var body: some View {
        VStack(spacing: 4) {
            if value == nil {
                Text("Tap or drag to log")
                    .font(.caption)
                    .foregroundStyle(CloveColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(CloveColors.secondaryText.opacity(0.16))
                        .frame(height: 8)

                    if let value {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.shared.accent)
                            .frame(width: progressWidth(for: value, totalWidth: geometry.size.width), height: 8)

                        Circle()
                            .fill(Theme.shared.accent)
                            .frame(width: isDragging ? 28 : 24, height: isDragging ? 28 : 24)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .shadow(color: .black.opacity(0.14), radius: 3, y: 1)
                            .position(
                                x: thumbPosition(for: value, totalWidth: geometry.size.width),
                                y: geometry.size.height / 2
                            )
                    }
                }
                .frame(height: 44)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            isDragging = true
                            let updated = rating(at: gesture.location.x, totalWidth: geometry.size.width)
                            if lastFeedbackValue != updated {
                                UISelectionFeedbackGenerator().selectionChanged()
                                lastFeedbackValue = updated
                            }
                            value = updated
                        }
                        .onEnded { _ in
                            isDragging = false
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                )
            }
            .frame(height: 44)

            HStack {
                Text("\(minValue)")
                Spacer()
                Text("\(maxValue)")
            }
            .font(CloveFonts.small())
            .foregroundStyle(CloveColors.secondaryText)
        }
        .accessibilityElement()
        .accessibilityLabel("Rating slider")
        .accessibilityValue(value.map { "\(Int($0)) out of \(maxValue)" } ?? "Not logged")
        .accessibilityAdjustableAction { direction in
            let current = value ?? Double((minValue + maxValue) / 2)
            let change = direction == .increment ? step : -step
            value = max(Double(minValue), min(Double(maxValue), current + Double(change)))
        }
    }

    private func rating(at xPosition: CGFloat, totalWidth: CGFloat) -> Double {
        guard totalWidth > 0 else { return Double(minValue) }
        let fraction = max(0, min(1, xPosition / totalWidth))
        let rawValue = Double(minValue) + Double(fraction) * Double(maxValue - minValue)
        return (rawValue / Double(step)).rounded() * Double(step)
    }

    private func progressWidth(for value: Double, totalWidth: CGFloat) -> CGFloat {
        totalWidth * CGFloat((value - Double(minValue)) / Double(maxValue - minValue))
    }

    private func thumbPosition(for value: Double, totalWidth: CGFloat) -> CGFloat {
        max(12, min(totalWidth - 12, progressWidth(for: value, totalWidth: totalWidth)))
    }
}

private struct TodayBinarySymptomInput: View {
    @Binding var value: Double?
    let label: String
    var onDelete: (() -> Void)?

    private var isNo: Bool { value == 0 }
    private var isYes: Bool { value.map { $0 > 0 } ?? false }

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(CloveColors.primaryText)
                .lineLimit(1)

            Spacer(minLength: 8)

            binaryButton(title: "No", icon: "xmark", isSelected: isNo, value: 0)
            binaryButton(title: "Yes", icon: "checkmark", isSelected: isYes, value: 10)

            if let onDelete {
                Menu {
                    Button("Remove", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption.bold())
                        .foregroundStyle(CloveColors.secondaryText)
                        .frame(width: 34, height: 36)
                }
                .accessibilityLabel("More options for \(label)")
            }
        }
        .padding(10)
        .background(CloveColors.background.opacity(0.55), in: RoundedRectangle(cornerRadius: CloveCorners.small))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(label), \(value == nil ? "not logged" : (isYes ? "yes" : "no"))")
    }

    private func binaryButton(
        title: String,
        icon: String,
        isSelected: Bool,
        value newValue: Double
    ) -> some View {
        Button {
            value = isSelected ? nil : newValue
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isSelected ? "\(icon).circle.fill" : "\(icon).circle")
                Text(title)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? Theme.shared.accent : CloveColors.secondaryText)
            .frame(minWidth: 54, minHeight: 36)
            .background(
                isSelected ? Theme.shared.accent.opacity(0.12) : Color.clear,
                in: Capsule()
            )
            .overlay {
                Capsule().stroke(CloveColors.secondaryText.opacity(isSelected ? 0 : 0.15), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) for \(label)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
