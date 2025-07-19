import SwiftUI

struct ThemeCustomizationView: View {
   @AppStorage(Constants.SELECTED_COLOR) private var selectedColor = ""
   
   @State private var appColor: Color = Theme.shared.accent
   
   var body: some View {
      VStack {
         Form {
            Section(header: Text("Theme")) {
               ColorPicker("App Color", selection: $appColor)
               Button("Reset") {
                  Theme.shared.accent = Color.accent
                  selectedColor = Color.accent.toString()
               }
               .disabled(Theme.shared.accent == Color.accent)
            }
            .onChange(of: appColor) { _, newValue in
               Theme.shared.accent = newValue
               selectedColor = newValue.toString()
            }
            
            Section(header: Text("Accesibility")) {
               Button("Set To Grayscale Theme") {
                  self.selectedColor = Color.gray.toString()
                  Theme.shared.accent = Color.gray
               }
            }
         }
      }
      .navigationTitle("Theme")
   }
}

#Preview {
   ThemeCustomizationView()
}
