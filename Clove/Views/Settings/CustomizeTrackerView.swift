import SwiftUI

struct CustomizeTrackerView: View {
   @Environment(UserSettingsViewModel.self) var viewModel
   @AppStorage(Constants.USE_SLIDER_INPUT) private var useSliderInput = true

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
                Toggle("Notes", isOn: $vm.settings.trackNotes)
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

            Section {
                Button("Save Changes") {
                    viewModel.save()
                }
            }
        }
        .navigationTitle("Customize Tracker")
    }
}
