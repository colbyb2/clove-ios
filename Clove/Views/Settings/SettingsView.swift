import SwiftUI

struct SettingsView: View {
   @State private var viewModel = UserSettingsViewModel()
   @State private var showExportSheet = false
   @State private var showMedicationSetup = false
   @State private var showMedicationTimeline = false
   @State private var showSymptomsSheet = false
   @State private var trackedSymptoms: [TrackedSymptom] = []
   
   // Get app version from bundle
   private var appVersion: String {
      let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
      let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
      
      if let build = build, build != version {
         return "\(version) (\(build))"
      } else {
         return version
      }
   }
   
   private func loadTrackedSymptoms() {
      trackedSymptoms = SymptomsRepo.shared.getTrackedSymptoms()
   }
   
   private func showTermsAndConditions() {
      // Find the terms and conditions popup from the available popups
      if let termsPopup = Popups.all.first(where: { $0.id == "termsAndConditions" }) {
         // Force show the popup by setting it directly, bypassing the UserDefaults check
         PopupManager.shared.currentPopup = termsPopup
      }
   }
   
   var body: some View {
      ZStack {
         Form {
             Section(header: Text("Customization")) {
               HStack {
                  Image(systemName: "gear")
                     .font(.system(size: 16, weight: .medium))
                     .foregroundStyle(Theme.shared.accent)
                  NavigationLink("Feature Selection") {
                     CustomizeTrackerView()
                        .environment(viewModel)
                  }
               }
               HStack {
                  Image(systemName: "paintpalette.fill")
                     .font(.system(size: 16, weight: .medium))
                     .foregroundStyle(Theme.shared.accent)
                  NavigationLink("Theme") {
                     ThemeCustomizationView()
                  }
               }
               
               HStack {
                  Image(systemName: "bell.fill")
                     .font(.system(size: 16, weight: .medium))
                     .foregroundStyle(Theme.shared.accent)
                  NavigationLink("Reminders") {
                     DailyReminderView()
                  }
               }
            }
            
            Section(header: Text("Insights")) {
               HStack {
                  Image(systemName: "sparkles")
                     .font(.system(size: 16, weight: .medium))
                     .foregroundStyle(Theme.shared.accent)
                  NavigationLink("Complexity") {
                     InsightsCustomizationView()
                  }
               }
            }
            
            Section(header: Text("Medication")) {
               Button(action: {
                  showMedicationSetup = true
                  // Haptic feedback
                  let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                  impactFeedback.impactOccurred()
               }) {
                  HStack {
                     Image(systemName: "pills")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.shared.accent)
                     
                     Text("Manage Medications")
                        .foregroundStyle(CloveColors.primaryText)
                     
                     Spacer()
                     
                     Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CloveColors.secondaryText)
                  }
               }
               .accessibilityLabel("Manage medications")
               .accessibilityHint("Add, edit, or remove medications for daily tracking")
               
               Button(action: {
                  showMedicationTimeline = true
                  // Haptic feedback
                  let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                  impactFeedback.impactOccurred()
               }) {
                  HStack {
                     Image(systemName: "clock")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.shared.accent)
                     
                     Text("Medication History")
                        .foregroundStyle(CloveColors.primaryText)
                     
                     Spacer()
                     
                     Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CloveColors.secondaryText)
                  }
               }
               .accessibilityLabel("Medication history")
               .accessibilityHint("View timeline of medication changes")
            }
            
            Section(header: Text("Symptoms")) {
               Button(action: {
                  showSymptomsSheet = true
                  // Haptic feedback
                  let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                  impactFeedback.impactOccurred()
               }) {
                  HStack {
                     Image(systemName: "bandage")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.shared.accent)
                     
                     Text("Manage Symptoms")
                        .foregroundStyle(CloveColors.primaryText)
                     
                     Spacer()
                     
                     Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CloveColors.secondaryText)
                  }
               }
               .accessibilityLabel("Manage symptoms")
               .accessibilityHint("Add, edit, or remove symptoms for daily tracking")
            }
            
            Section(header: Text("Data")) {
               Button(action: {
                  showExportSheet = true
                  // Haptic feedback
                  let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                  impactFeedback.impactOccurred()
               }) {
                  HStack {
                     Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.shared.accent)
                     
                     Text("Export Data")
                        .foregroundStyle(CloveColors.primaryText)
                     
                     Spacer()
                  }
               }
               .accessibilityLabel("Export data")
               .accessibilityHint("Export your health data as a CSV file")
               
               HStack {
                  Image(systemName: "square.and.arrow.down")
                     .font(.system(size: 16, weight: .medium))
                     .foregroundStyle(Theme.shared.accent)
                  NavigationLink("Import Data") {
                     DataImportView()
                  }
               }
               .accessibilityLabel("Import data")
               .accessibilityHint("Import your health data from a CSV file")
            }
            
            Section(header: Text("Help")) {
               HStack {
                  Image(systemName: "lightbulb.fill")
                     .font(.system(size: 16, weight: .medium))
                     .foregroundStyle(Theme.shared.accent)
                  NavigationLink("Tutorials") {
                     TutorialSettingsView()
                        .environment(TutorialManager.shared)
                  }
               }

               HStack {
                  Image(systemName: "clock.arrow.circlepath")
                     .font(.system(size: 16, weight: .medium))
                     .foregroundStyle(Theme.shared.accent)
                  NavigationLink("What's New") {
                     ChangelogView()
                  }
               }
               .accessibilityLabel("What's new")
               .accessibilityHint("View changelog and version history")

               Button(action: {
                  showTermsAndConditions()
                  // Haptic feedback
                  let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                  impactFeedback.impactOccurred()
               }) {
                  HStack {
                     Image(systemName: "doc.text.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.shared.accent)

                     Text("View Terms and Conditions")
                        .foregroundStyle(CloveColors.primaryText)

                     Spacer()

                     Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CloveColors.secondaryText)
                  }
               }
               .accessibilityLabel("View terms and conditions")
               .accessibilityHint("Display the app's terms and conditions")
            }
            
            // Version indicator section
            Section(footer:
                     HStack {
               Spacer()
               Text("Clove\nVersion \(appVersion)")
                  .font(.footnote)
                  .multilineTextAlignment(.center)
                  .foregroundColor(.secondary)
               Spacer()
            }
            ) {
               EmptyView() // No row content
            }
         }
      }
      .navigationTitle("Settings")
      .onAppear {
         viewModel.load()
         loadTrackedSymptoms()
      }
      .sheet(isPresented: $showExportSheet) {
         DataExportSheet()
      }
      .sheet(isPresented: $showMedicationSetup) {
         MedicationSetupSheet()
      }
      .sheet(isPresented: $showMedicationTimeline) {
         MedicationTimelineView()
      }
      .sheet(isPresented: $showSymptomsSheet) {
         EditSymptomsSheet(
            trackedSymptoms: SymptomsRepo.shared.getTrackedSymptoms(),
            refresh: loadTrackedSymptoms
         )
         .onDisappear {
            loadTrackedSymptoms() // Refresh symptoms list when sheet closes
         }
      }
   }
}

#Preview {
   NavigationView {
      SettingsView()
   }
}
