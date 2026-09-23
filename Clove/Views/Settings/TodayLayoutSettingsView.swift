import SwiftUI

struct TodayLayoutSettingsView: View {
    let settings: UserSettings
    @State private var preferences = TodayLayoutPreferences.load()
    @AppStorage(Constants.FOCUSED_CHECK_IN) private var focusedCheckIn = false

    private var enabledModules: [TodayModule] {
        preferences.order.filter(moduleIsEnabled)
    }

    var body: some View {
        List {
            Section {
                Toggle("Focused check-in", isOn: $focusedCheckIn)
            } footer: {
                Text("Focused mode shows only modules marked Essential. It highlights unanswered items without requiring you to complete them.")
            }

            Section {
                ForEach(enabledModules) { module in
                    moduleRow(module)
                }
                .onMove(perform: moveModules)
            } header: {
                Text("Today Modules")
            } footer: {
                Text("Only enabled trackers appear here. Use Edit to drag them into your preferred order. The menu controls visibility, default expansion, and focused-mode essentials.")
            }
        }
        .navigationTitle("Arrange Today")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .onAppear { preferences = .load() }
    }

    private func moduleRow(_ module: TodayModule) -> some View {
        HStack(spacing: 12) {
            Image(systemName: module.icon)
                .foregroundStyle(Theme.shared.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(module.title)
                    .foregroundStyle(CloveColors.primaryText)
                HStack(spacing: 6) {
                    if preferences.essentials.contains(module) {
                        badge("Essential", icon: "star.fill")
                    }
                    if preferences.collapsed.contains(module) {
                        badge("Collapsed", icon: "rectangle.compress.vertical")
                    }
                    if preferences.hidden.contains(module) {
                        badge("Hidden", icon: "eye.slash.fill")
                    }
                }
            }

            Spacer()

            Menu {
                Button {
                    toggle(module, in: \TodayLayoutPreferences.essentials)
                } label: {
                    Label(
                        preferences.essentials.contains(module) ? "Remove from Essentials" : "Mark Essential",
                        systemImage: preferences.essentials.contains(module) ? "star.slash" : "star"
                    )
                }
                Button {
                    toggle(module, in: \TodayLayoutPreferences.collapsed)
                } label: {
                    Label(
                        preferences.collapsed.contains(module) ? "Expand by Default" : "Collapse by Default",
                        systemImage: preferences.collapsed.contains(module) ? "rectangle.expand.vertical" : "rectangle.compress.vertical"
                    )
                }
                Button {
                    toggle(module, in: \TodayLayoutPreferences.hidden)
                } label: {
                    Label(
                        preferences.hidden.contains(module) ? "Show on Today" : "Hide from Today",
                        systemImage: preferences.hidden.contains(module) ? "eye" : "eye.slash"
                    )
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(Theme.shared.accent)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Options for \(module.title)")
        }
        .opacity(preferences.hidden.contains(module) ? 0.55 : 1)
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
        var reorderedEnabled = enabledModules
        reorderedEnabled.move(fromOffsets: source, toOffset: destination)
        let disabled = preferences.order.filter { !moduleIsEnabled($0) }
        preferences.order = reorderedEnabled + disabled
        preferences.save()
    }

    private func moduleIsEnabled(_ module: TodayModule) -> Bool {
        switch module {
        case .mood: settings.trackMood
        case .pain: settings.trackPain
        case .energy: settings.trackEnergy
        case .hydration: settings.trackHydration
        case .symptoms: settings.trackSymptoms
        case .meals: settings.trackMeals
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
