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
            }
            
            // Version indicator section
            Section(footer:
                     HStack {
               Spacer()
               Text("Clove\nVersion 1.0.0")
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
