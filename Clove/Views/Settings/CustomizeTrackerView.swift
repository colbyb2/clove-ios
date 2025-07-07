import SwiftUI

struct CustomizeTrackerView: View {
   @Environment(UserSettingsViewModel.self) var viewModel
   @AppStorage(Constants.USE_SLIDER_INPUT) private var useSliderInput = true
   @AppStorage(Constants.SELECTED_COLOR) private var selectedColor = ""
   
   @State private var appColor: Color = Theme.shared.accent

    var body: some View {
        Form {
            @Bindable var vm = viewModel
            Section(header: Text("What do you want to track?")) {
                Toggle("Mood", isOn: $vm.settings.trackMood)
                Toggle("Pain", isOn: $vm.settings.trackPain)
                Toggle("Energy", isOn: $vm.settings.trackEnergy)
                Toggle("Symptoms", isOn: $vm.settings.trackSymptoms)
                Toggle("Meals", isOn: $vm.settings.trackMeals)
                Toggle("Activities", isOn: $vm.settings.trackActivities)
                Toggle("Medications", isOn: $vm.settings.trackMeds)
                Toggle("Weather", isOn: $vm.settings.trackWeather)
                Toggle("Flare Toggle", isOn: $vm.settings.showFlareToggle)
            }
            
            Section(header: Text("Input Method")) {
                Toggle("Use Slider Input", isOn: $useSliderInput)
                    .onChange(of: useSliderInput) { _, newValue in
                        // Haptic feedback when toggling
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                
                Text(useSliderInput ? "Rating inputs will use sliders by default" : "Rating inputs will use plus/minus buttons by default")
                    .font(.footnote)
                    .foregroundStyle(CloveColors.secondaryText)
            }
           
           Section(header: Text("Theme")) {
              ColorPicker("App Color", selection: $appColor)
              Button("Reset") {
                 Theme.shared.accent = Color.accent
                 selectedColor = Color.accent.toString()
              }
              .disabled(Theme.shared.accent == Color.accent)
           }

            Section {
                Button("Save Changes") {
                    viewModel.save()
                }
            }
        }
        .navigationTitle("Customize Tracker")
        .onChange(of: appColor) { _, newValue in
           Theme.shared.accent = newValue
           selectedColor = newValue.toString()
        }
    }
}
