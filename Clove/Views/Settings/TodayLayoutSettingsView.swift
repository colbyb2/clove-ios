import SwiftUI

struct TodayLayoutSettingsView: View {
    let settings: UserSettings
    @State private var preferences = TodayLayoutPreferences.load()
    @State private var customDefinitions: [CustomMetricDefinition] = []
    @State private var loadError: String?
    @AppStorage(Constants.FOCUSED_CHECK_IN) private var focusedCheckIn = false

    private var enabledItems: [TodayLayoutItem] {
        preferences.items(customMetricIDs: customDefinitions.map(\.id)).filter(itemIsEnabled)
    }

    var body: some View {
        List {
            Section {
                Toggle("Focused check-in", isOn: $focusedCheckIn)
            } footer: {
                Text("Focused mode shows only trackers marked Essential. It highlights unanswered items without requiring you to complete them.")
            }

            Section {
                ForEach(enabledItems) { item in
                    itemRow(item)
                }
                .onMove(perform: moveModules)
            } header: {
                Text("Today Trackers")
            } footer: {
                Text("Only enabled trackers appear here. Use Edit to drag them into your preferred order. The menu controls visibility, default expansion, and focused-mode essentials.")
            }
            if let loadError {
                Section { Text(loadError).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Arrange Today")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .onAppear {
            preferences = .load()
            do {
                customDefinitions = try CustomMetricsRepo.shared.definitions()
                preferences.setItems(preferences.items(customMetricIDs: customDefinitions.map(\.id)))
                preferences.save()
                loadError = nil
            } catch {
                loadError = "Custom metrics could not be loaded. Please reopen this screen to try again."
            }
        }
    }

    private func itemRow(_ item: TodayLayoutItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon(for: item))
                .foregroundStyle(tint(for: item))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title(for: item))
                    .foregroundStyle(CloveColors.primaryText)
                HStack(spacing: 6) {
                    if preferences.isEssential(item) {
                        badge("Essential", icon: "star.fill")
                    }
                    if case .module(let module) = item, preferences.collapsed.contains(module) {
                        badge("Collapsed", icon: "rectangle.compress.vertical")
                    }
                    if preferences.isHidden(item) {
                        badge("Hidden", icon: "eye.slash.fill")
                    }
                }
            }

            Spacer()

            Menu {
                Button {
                    preferences.setEssential(!preferences.isEssential(item), for: item)
                    preferences.save()
                } label: {
                    Label(
                        preferences.isEssential(item) ? "Remove from Essentials" : "Mark Essential",
                        systemImage: preferences.isEssential(item) ? "star.slash" : "star"
                    )
                }
                if case .module(let module) = item {
                    Button {
                        toggle(module, in: \TodayLayoutPreferences.collapsed)
                    } label: {
                        Label(
                            preferences.collapsed.contains(module) ? "Expand by Default" : "Collapse by Default",
                            systemImage: preferences.collapsed.contains(module) ? "rectangle.expand.vertical" : "rectangle.compress.vertical"
                        )
                    }
                }
                Button {
                    preferences.setHidden(!preferences.isHidden(item), for: item)
                    preferences.save()
                } label: {
                    Label(
                        preferences.isHidden(item) ? "Show on Today" : "Hide from Today",
                        systemImage: preferences.isHidden(item) ? "eye" : "eye.slash"
                    )
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(Theme.shared.accent)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Options for \(title(for: item))")
        }
        .opacity(preferences.isHidden(item) ? 0.55 : 1)
    }

    private func badge(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(CloveColors.secondaryText)
    }

    private func toggle(_ module: TodayModule, in keyPath: WritableKeyPath<TodayLayoutPreferences, Set<TodayModule>>) {
        if preferences[keyPath: keyPath].contains(module) {
            preferences[keyPath: keyPath].remove(module)
        } else {
            preferences[keyPath: keyPath].insert(module)
        }
        preferences.save()
    }

    private func moveModules(from source: IndexSet, to destination: Int) {
        var reordered = enabledItems
        reordered.move(fromOffsets: source, toOffset: destination)
        let disabled = preferences.items(customMetricIDs: customDefinitions.map(\.id)).filter { !itemIsEnabled($0) }
        preferences.setItems(reordered + disabled)
        preferences.save()
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
        if case .customMetric(let id) = item,
           let definition = customDefinitions.first(where: { $0.id == id }) {
            return Color(hex: definition.colorHex)
        }
        return Theme.shared.accent
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
