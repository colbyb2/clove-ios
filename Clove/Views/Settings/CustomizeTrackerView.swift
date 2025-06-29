import SwiftUI

struct CustomizeTrackerView: View {
   @Environment(UserSettingsViewModel.self) var viewModel

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
                Toggle("Flare Toggle", isOn: $vm.settings.showFlareToggle)
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
