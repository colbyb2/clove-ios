import SwiftUI

struct SettingsView: View {
   @State private var viewModel = UserSettingsViewModel()
   @State private var showExportSheet = false
   
   var body: some View {
      ZStack {
         Form {
            Section(header: Text("Customization")) {
               NavigationLink("Feature Selection") {
                  CustomizeTrackerView()
                     .environment(viewModel)
               }
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
                        .foregroundStyle(CloveColors.accent)
                     
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
   }
}

#Preview {
   NavigationView {
      SettingsView()
   }
}
