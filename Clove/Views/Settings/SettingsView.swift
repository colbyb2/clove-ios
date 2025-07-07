import SwiftUI

struct SettingsView: View {
   @State private var viewModel = UserSettingsViewModel()
   @State private var showExportSheet = false
   @State private var showMedicationSetup = false
   @State private var showMedicationTimeline = false
   
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
         }
      }
      .navigationTitle("Settings")
      .onAppear {
          viewModel.load()
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
   }
}

#Preview {
   NavigationView {
      SettingsView()
   }
}
