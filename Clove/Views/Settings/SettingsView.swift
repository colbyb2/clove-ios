import SwiftUI

struct SettingsView: View {
    @State private var viewModel = UserSettingsViewModel()

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    TrackingAndLoggingSettingsView(viewModel: viewModel)
                } label: {
                    SettingsCategoryLabel(icon: "checklist", color: .blue, title: "Tracking & Logging",
                                          subtitle: "Features, goals, symptoms, medications, and daily logging")
                }

                NavigationLink {
                    InsightsSettingsView()
                } label: {
                    SettingsCategoryLabel(icon: "sparkles", color: .purple, title: "Insights",
                                          subtitle: "Dashboard complexity and local diagnostics")
                }

                NavigationLink {
                    AppearanceAndAlertsSettingsView()
                } label: {
                    SettingsCategoryLabel(icon: "paintpalette.fill", color: .pink, title: "Appearance & Alerts",
                                          subtitle: "Theme and reminders")
                }
            }

            Section {
                NavigationLink {
                    DataSettingsView()
                } label: {
                    SettingsCategoryLabel(icon: "externaldrive.fill", color: .green, title: "Data",
                                          subtitle: "Import and export your records")
                }

                NavigationLink {
                    HelpAndAboutSettingsView()
                } label: {
                    SettingsCategoryLabel(icon: "questionmark.circle.fill", color: Theme.shared.accent,
                                          title: "Help & About", subtitle: "Tutorials, updates, terms, and app version")
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear { viewModel.load() }
    }
}

private struct SettingsCategoryLabel: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(CloveColors.primaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(CloveColors.secondaryText)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct TrackingAndLoggingSettingsView: View {
    let viewModel: UserSettingsViewModel
    @State private var showSymptomsSheet = false
    @State private var trackedSymptoms: [TrackedSymptom] = []
    @AppStorage(Constants.HYDRATION_GOAL_OUNCES) private var hydrationGoalOunces = 64

    var body: some View {
        @Bindable var bindableViewModel = viewModel
        Form {
            Section("Daily Tracker") {
                NavigationLink {
                    CustomizeTrackerView().environment(viewModel)
                } label: {
                    Label("Choose What to Track", systemImage: "checklist")
                }

                Toggle(isOn: $bindableViewModel.settings.autoSaveEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto Save Daily Changes")
                        Text("Save edits shortly after you make them")
                            .font(.caption).foregroundStyle(CloveColors.secondaryText)
                    }
                }
                .onChange(of: viewModel.settings.autoSaveEnabled) { _, _ in viewModel.save() }
            }

            Section("Goals") {
                NavigationLink {
                    HydrationSettingsView()
                } label: {
                    SettingsRowLabel(icon: "drop.fill", color: .blue, title: "Hydration Goal",
                                     detail: "\(hydrationGoalOunces) oz per day")
                }
            }

            Section("Tracked Items") {
                Button {
                    showSymptomsSheet = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    SettingsRowLabel(
                        icon: "bandage.fill",
                        color: .orange,
                        title: "Tracked Symptoms",
                        detail: "Choose what appears in your daily tracker"
                    )
                }
                .accessibilityHint("Add, edit, or remove tracked symptoms")

                NavigationLink {
                    MedicationSettingsView()
                } label: {
                    SettingsRowLabel(icon: "pills.fill", color: .purple, title: "Medications",
                                     detail: "Manage medications and history")
                }

                NavigationLink {
                    CycleOverviewView()
                } label: {
                    SettingsRowLabel(icon: "calendar", color: .red, title: "Cycle",
                                     detail: "History and predictions")
                }

                NavigationLink {
                    FoodAndActivitySettingsView()
                } label: {
                    SettingsRowLabel(icon: "fork.knife", color: .green, title: "Food & Activities",
                                     detail: "Favorites and saved items")
                }
            }
        }
        .navigationTitle("Tracking & Logging")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadTrackedSymptoms() }
        .sheet(isPresented: $showSymptomsSheet) {
            EditSymptomsSheet(trackedSymptoms: trackedSymptoms, refresh: loadTrackedSymptoms)
                .onDisappear { loadTrackedSymptoms() }
        }
    }

    private func loadTrackedSymptoms() {
        trackedSymptoms = SymptomsRepo.shared.getTrackedSymptoms()
    }
}

private struct MedicationSettingsView: View {
    @State private var showSetup = false
    @State private var showTimeline = false

    var body: some View {
        Form {
            Section {
                Button { showSetup = true } label: {
                    SettingsButtonRow(icon: "pills.fill", color: .purple, title: "Manage Medications")
                }
                .accessibilityHint("Add, edit, or remove medications")

                Button { showTimeline = true } label: {
                    SettingsButtonRow(icon: "clock.fill", color: .blue, title: "Medication History")
                }
                .accessibilityHint("View medication changes over time")
            }
        }
        .navigationTitle("Medications")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSetup) { MedicationSetupSheet() }
        .sheet(isPresented: $showTimeline) { MedicationTimelineView() }
    }
}

private struct FoodAndActivitySettingsView: View {
    var body: some View {
        Form {
            Section {
                NavigationLink {
                    ManageFoodsView()
                } label: {
                    SettingsRowLabel(icon: "fork.knife", color: .green, title: "Manage Foods",
                                     detail: "Organize foods and favorites")
                }
                NavigationLink {
                    ManageActivitiesView()
                } label: {
                    SettingsRowLabel(icon: "figure.run", color: .blue, title: "Manage Activities",
                                     detail: "Organize activities and favorites")
                }
            }
        }
        .navigationTitle("Food & Activities")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct InsightsSettingsView: View {
    @AppStorage(Constants.LOCAL_ANALYTICS_DIAGNOSTICS) private var localDiagnostics = true

    var body: some View {
        Form {
            Section("Display") {
                NavigationLink {
                    InsightsCustomizationView()
                } label: {
                    SettingsRowLabel(icon: "slider.horizontal.3", color: .purple, title: "Dashboard Complexity",
                                     detail: "Choose which insight features appear")
                }
            }
            Section("Privacy & Reliability") {
                Toggle(isOn: $localDiagnostics) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Local Diagnostics")
                        Text("Stores aggregate reliability and speed counters only on this device")
                            .font(.caption).foregroundStyle(CloveColors.secondaryText)
                    }
                }
                .onChange(of: localDiagnostics) { _, enabled in
                    AnalyticsDiagnosticsRecorder.shared.isEnabled = enabled
                }
            }
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AppearanceAndAlertsSettingsView: View {
    var body: some View {
        Form {
            Section("Appearance") {
                NavigationLink {
                    ThemeCustomizationView()
                } label: {
                    SettingsRowLabel(icon: "paintpalette.fill", color: .pink, title: "Theme",
                                     detail: "Colors and appearance")
                }
            }
            Section("Alerts") {
                NavigationLink {
                    DailyReminderView()
                } label: {
                    SettingsRowLabel(icon: "bell.fill", color: .orange, title: "Reminders",
                                     detail: "Daily logging notifications")
                }
            }
        }
        .navigationTitle("Appearance & Alerts")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DataSettingsView: View {
    @State private var showExportSheet = false

    var body: some View {
        Form {
            Section {
                Button { showExportSheet = true } label: {
                    SettingsButtonRow(icon: "square.and.arrow.up", color: .blue, title: "Export Data")
                }
                .accessibilityHint("Export health data as a CSV file")

                NavigationLink {
                    DataImportView()
                } label: {
                    SettingsRowLabel(icon: "square.and.arrow.down", color: .green, title: "Import Data",
                                     detail: "Import records from a CSV file")
                }
            }
        }
        .navigationTitle("Data")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showExportSheet) { DataExportSheet() }
    }
}

private struct HelpAndAboutSettingsView: View {
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        return build.map { $0 == version ? version : "\(version) (\($0))" } ?? version
    }

    var body: some View {
        Form {
            Section("Help") {
                NavigationLink {
                    TutorialSettingsView().environment(TutorialManager.shared)
                } label: {
                    SettingsRowLabel(icon: "lightbulb.fill", color: .yellow, title: "Tutorials",
                                     detail: "Learn how to use Clove")
                }
                NavigationLink {
                    ChangelogView()
                } label: {
                    SettingsRowLabel(icon: "clock.arrow.circlepath", color: .blue, title: "What's New",
                                     detail: "Recent changes and improvements")
                }
            }

            Section("About") {
                Button { showTermsAndConditions() } label: {
                    SettingsButtonRow(icon: "doc.text.fill", color: .gray, title: "Terms & Conditions")
                }
                LabeledContent("Version", value: appVersion)
            }
        }
        .navigationTitle("Help & About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func showTermsAndConditions() {
        if let termsPopup = Popups.all.first(where: { $0.id == "termsAndConditions" }) {
            PopupManager.shared.currentPopup = termsPopup
        }
    }
}

private struct SettingsRowLabel: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(CloveColors.primaryText)
                Text(detail).font(.caption).foregroundStyle(CloveColors.secondaryText)
            }
        }
    }
}

private struct SettingsButtonRow: View {
    let icon: String
    let color: Color
    let title: String

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(color).frame(width: 24)
            Text(title).foregroundStyle(CloveColors.primaryText)
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(CloveColors.secondaryText)
        }
        .contentShape(Rectangle())
    }
}

private struct HydrationSettingsView: View {
    @AppStorage(Constants.HYDRATION_GOAL_OUNCES) private var hydrationGoalOunces = 64
    private let suggestedGoals = [48, 64, 80, 96]

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.blue)
                    Text("\(hydrationGoalOunces) oz")
                        .font(.system(.largeTitle, design: .rounded).bold())
                    Text("per day")
                        .font(.subheadline)
                        .foregroundStyle(CloveColors.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)

                Stepper(
                    "Daily goal",
                    value: $hydrationGoalOunces,
                    in: 8...256,
                    step: 8
                )
                .accessibilityValue("\(hydrationGoalOunces) fluid ounces per day")
            } header: {
                Text("Your Goal")
            } footer: {
                Text("Adjusts in eight-ounce increments. Changes are saved automatically.")
            }

            Section("Quick Choices") {
                HStack(spacing: 8) {
                    ForEach(suggestedGoals, id: \.self) { goal in
                        Button("\(goal) oz") {
                            hydrationGoalOunces = goal
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .tint(hydrationGoalOunces == goal ? Theme.shared.accent : CloveColors.card)
                        .foregroundStyle(hydrationGoalOunces == goal ? Color.white : CloveColors.primaryText)
                    }
                }
            }

            Section("How It Is Used") {
                Label("The dashed chart line shows this daily goal.", systemImage: "line.diagonal")
                Label("Green bars meet or exceed it; purple bars are below it.", systemImage: "chart.bar.fill")
                Text("This is a personal tracking target, not medical advice. Hydration needs vary by person and circumstance.")
                    .font(.caption)
                    .foregroundStyle(CloveColors.secondaryText)
            }
        }
        .navigationTitle("Hydration")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        SettingsView()
    }
}
