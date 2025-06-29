import SwiftUI

struct SettingsView: View {
   @State private var viewModel = UserSettingsViewModel()
   
   var body: some View {
      ZStack {
         Form {
            Section(header: Text("Customization")) {
               NavigationLink("Feature Selection") {
                  CustomizeTrackerView()
                     .environment(viewModel)
               }
            }
         }
      }
      .navigationTitle("Settings")
      .onAppear {
          viewModel.load()
      }
   }
}

#Preview {
   NavigationView {
      SettingsView()
   }
}
