import SwiftUI

struct TodayLayoutSettingsView: View {
    let settings: UserSettings
    @State private var preferences = TodayLayoutPreferences.load()
    @State private var customDefinitions: [CustomMetricDefinition] = []
    @State private var loadError: String?
    @AppStorage(Constants.FOCUSED_CHECK_IN) private var focusedCheckIn = false

    private var allItems: [TodayLayoutItem] {
        preferences.items(customMetricIDs: customDefinitions.map(\.id))
    }

    private var enabledItems: [TodayLayoutItem] {
        allItems.filter(itemIsEnabled)
    }

    private var essentialCount: Int {
        enabledItems.filter { preferences.isEssential($0) && !preferences.isHidden($0) }.count
    }

    var body: some View {
        List {
            focusedSection

            if enabledItems.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Trackers Enabled",
                        systemImage: "square.stack.3d.up.slash",
                        description: Text("Turn on trackers in Choose What to Track to arrange them here.")
                    )
                    .listRowBackground(Color.clear)
                }
            } else {
                trackersSection
            }

            if let loadError {
                Section {
                    Label(loadError, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(CloveColors.error)
                        .listRowBackground(CloveColors.card)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(CloveColors.background)
        // Reorder handles are always visible, so there's no hidden Edit mode to discover.
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Arrange Today")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: preferences)
        .sensoryFeedback(.selection, trigger: focusedCheckIn)
        .onAppear(perform: load)
    }

    // MARK: - Sections

    private var focusedSection: some View {
        Section {
            Toggle(isOn: $focusedCheckIn.animation()) {
                HStack(spacing: 12) {
                    iconTile("scope", tint: Theme.shared.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Focused check-in")
                            .font(.body.weight(.medium))
                            .foregroundStyle(CloveColors.primaryText)
                        Text(essentialSummary)
                            .font(.caption)
                            .foregroundStyle(CloveColors.secondaryText)
                            .contentTransition(.numericText())
                    }
                }
            }
            .tint(Theme.shared.accent)
            .padding(.vertical, 2)
            .listRowBackground(CloveColors.card)
        } footer: {
            if focusedCheckIn && essentialCount == 0 && !enabledItems.isEmpty {
                Label("Today will be empty until you star at least one tracker below.", systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(CloveColors.orange)
            } else {
                Text("Shows only your starred essentials on Today. Unanswered ones are highlighted, but nothing is required.")
            }
        }
    }

    private var trackersSection: some View {
        Section {
            ForEach(enabledItems) { item in
                TrackerLayoutRow(
                    title: title(for: item),
                    icon: icon(for: item),
                    tint: tint(for: item),
                    isEssential: preferences.isEssential(item),
                    isHidden: preferences.isHidden(item),
                    collapsible: collapsibleModule(for: item) != nil,
                    isCollapsed: collapsibleModule(for: item).map { preferences.collapsed.contains($0) } ?? false,
                    toggleEssential: { update { $0.setEssential(!$0.isEssential(item), for: item) } },
                    toggleHidden: { update { $0.setHidden(!$0.isHidden(item), for: item) } },
                    toggleCollapsed: {
                        guard let module = collapsibleModule(for: item) else { return }
                        update { prefs in
                            if prefs.collapsed.contains(module) { prefs.collapsed.remove(module) } else { prefs.collapsed.insert(module) }
                        }
                    }
                )
                .listRowBackground(CloveColors.card)
            }
            .onMove(perform: moveItems)
        } header: {
            Text("Order on Today")
        } footer: {
            Text("Drag \(Image(systemName: "line.3.horizontal")) to reorder. Tap \(Image(systemName: "star")) to mark a tracker essential for focused check-ins.")
        }
    }

    private var essentialSummary: String {
        switch essentialCount {
        case 0: "No essentials starred"
        case 1: "1 essential tracker"
        default: "\(essentialCount) essential trackers"
        }
    }

    // MARK: - Actions

    private func load() {
        preferences = .load()
        do {
            customDefinitions = try CustomMetricsRepo.shared.definitions()
            preferences.setItems(allItems)
            preferences.save()
            loadError = nil
        } catch {
            loadError = "Custom metrics couldn't be loaded. Reopen this screen to try again."
        }
    }

    private func update(_ change: (inout TodayLayoutPreferences) -> Void) {
        withAnimation(.snappy(duration: 0.25)) {
            change(&preferences)
        }
        preferences.save()
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        var reordered = enabledItems
        reordered.move(fromOffsets: source, toOffset: destination)
        let disabled = allItems.filter { !itemIsEnabled($0) }
        preferences.setItems(reordered + disabled)
        preferences.save()
    }

    // MARK: - Item metadata

    private func collapsibleModule(for item: TodayLayoutItem) -> TodayModule? {
        if case .module(let module) = item { return module }
        return nil
    }

    private func itemIsEnabled(_ item: TodayLayoutItem) -> Bool {
        switch item {
        case .module(let module): moduleIsEnabled(module)
        case .customMetric(let id): settings.trackCustomMetrics && customDefinitions.contains { $0.id == id && $0.isActive }
        }
    }

    private func title(for item: TodayLayoutItem) -> String {
        switch item {
        case .module(let module): module.title
        case .customMetric(let id): customDefinitions.first { $0.id == id }?.name ?? "Metric"
        }
    }

    private func icon(for item: TodayLayoutItem) -> String {
        switch item {
        case .module(let module): module.icon
        case .customMetric(let id): customDefinitions.first { $0.id == id }?.icon ?? "number"
        }
    }

    private func tint(for item: TodayLayoutItem) -> Color {
        switch item {
        case .module(let module):
            return module.layoutTint
        case .customMetric(let id):
            if let definition = customDefinitions.first(where: { $0.id == id }) {
                return Color(hex: definition.colorHex)
            }
            return Theme.shared.accent
        }
    }

    private func moduleIsEnabled(_ module: TodayModule) -> Bool {
        switch module {
        case .customMetrics: false
        case .mood: settings.trackMood
        case .pain: settings.trackPain
        case .energy: settings.trackEnergy
        case .hydration: settings.trackHydration
        case .sleep: settings.trackSleep
        case .symptoms: settings.trackSymptoms
        case .meals: settings.trackMeals
        case .plans: false
        case .activities: settings.trackActivities
        case .medications: settings.trackMeds
        case .weather: settings.trackWeather
        case .bowelMovements: settings.trackBowelMovements
        case .cycle: settings.trackCycle
        case .notes: settings.trackNotes
        case .flare: settings.showFlareToggle
        }
    }
}

// MARK: - Row

private struct TrackerLayoutRow: View {
    let title: String
    let icon: String
    let tint: Color
    let isEssential: Bool
    let isHidden: Bool
    let collapsible: Bool
    let isCollapsed: Bool
    let toggleEssential: () -> Void
    let toggleHidden: () -> Void
    let toggleCollapsed: () -> Void

    private var status: String? {
        var parts: [String] = []
        if isHidden { parts.append("Hidden from Today") }
        if isCollapsed { parts.append("Starts collapsed") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            iconTile(icon, tint: isHidden ? CloveColors.secondaryText : tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(isHidden ? CloveColors.secondaryText : CloveColors.primaryText)
                    .strikethrough(isHidden, color: CloveColors.secondaryText.opacity(0.6))
                    .lineLimit(1)
                if let status {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(CloveColors.secondaryText)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Spacer(minLength: 8)

            Button(action: toggleEssential) {
                Image(systemName: isEssential ? "star.fill" : "star")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isEssential ? CloveColors.yellow : CloveColors.secondaryText.opacity(0.5))
                    .symbolEffect(.bounce, value: isEssential)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(isHidden)
            .opacity(isHidden ? 0.4 : 1)
            .accessibilityLabel(isEssential ? "Remove \(title) from essentials" : "Mark \(title) essential")
            .accessibilityAddTraits(isEssential ? .isSelected : [])

            Menu {
                Button(action: toggleHidden) {
                    Label(isHidden ? "Show on Today" : "Hide from Today",
                          systemImage: isHidden ? "eye" : "eye.slash")
                }
                if collapsible {
                    Button(action: toggleCollapsed) {
                        Label(isCollapsed ? "Start Expanded" : "Start Collapsed",
                              systemImage: isCollapsed ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CloveColors.secondaryText)
                    .frame(width: 32, height: 36)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .accessibilityLabel("More options for \(title)")
        }
        .padding(.vertical, 4)
        .frame(minHeight: 44)
        .accessibilityElement(children: .contain)
    }
}

private func iconTile(_ systemName: String, tint: Color) -> some View {
    Image(systemName: systemName)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(tint)
        .frame(width: 32, height: 32)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityHidden(true)
}

private extension TodayModule {
    /// Matches the tile colors in Choose What to Track so a tracker reads the same everywhere.
    var layoutTint: Color {
        switch self {
        case .mood: .blue
        case .pain: .red
        case .energy: .yellow
        case .hydration: .blue
        case .sleep: .indigo
        case .symptoms: .orange
        case .meals: .green
        case .plans: .teal
        case .activities: .cyan
        case .medications: .purple
        case .weather: .mint
        case .bowelMovements: Color(hex: "9b6230")
        case .cycle: Color(hex: "ff6b9d")
        case .notes: .indigo
        case .flare: .pink
        case .customMetrics: .purple
        }
    }
}
