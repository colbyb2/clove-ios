import SwiftUI

struct CustomizeTrackerView: View {
    @State private var viewModel = UserSettingsViewModel()

    var body: some View {
        Form {
            Section(header: Text("What do you want to track?")) {
                Toggle("Mood", isOn: $viewModel.settings.trackMood)
                Toggle("Pain", isOn: $viewModel.settings.trackPain)
                Toggle("Energy", isOn: $viewModel.settings.trackEnergy)
                Toggle("Symptoms", isOn: $viewModel.settings.trackSymptoms)
                Toggle("Meals", isOn: $viewModel.settings.trackMeals)
                Toggle("Activities", isOn: $viewModel.settings.trackActivities)
                Toggle("Medications", isOn: $viewModel.settings.trackMeds)
                Toggle("Flare Toggle", isOn: $viewModel.settings.showFlareToggle)
            }

            Section {
                Button("Save Changes") {
                    viewModel.save()
                }
            }
        }
        .navigationTitle("Customize Tracker")
        .onAppear {
            viewModel.load()
        }
    }
}
