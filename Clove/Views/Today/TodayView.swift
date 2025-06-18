import SwiftUI

struct TodayView: View {
    @State private var viewModel = TodayViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                if viewModel.settings.trackMood {
                    Text("Mood (1-5)").font(.headline)
                    Stepper(value: $viewModel.mood, in: 1...5) {
                        Text("Mood: \(viewModel.mood)")
                    }
                }

                if viewModel.settings.trackPain {
                    Text("Pain Level (0-10)").font(.headline)
                    Slider(value: $viewModel.painLevel, in: 0...10, step: 1)
                    Text("Pain: \(Int(viewModel.painLevel))")
                }

                if viewModel.settings.trackEnergy {
                    Text("Energy (0-10)").font(.headline)
                    Slider(value: $viewModel.energyLevel, in: 0...10, step: 1)
                    Text("Energy: \(Int(viewModel.energyLevel))")
                }

                if viewModel.settings.trackSymptoms {
                    Text("Symptom Ratings").font(.headline)
                    ForEach(viewModel.symptomRatings.indices, id: \.self) { i in
                        let symptom = viewModel.symptomRatings[i]
                        VStack(alignment: .leading) {
                            Text(symptom.symptomName)
                            Slider(value: $viewModel.symptomRatings[i].ratingDouble, in: 0...10, step: 1)
                            Text("Rating: \(Int(viewModel.symptomRatings[i].ratingDouble))")
                        }
                    }
                }

                Toggle("Flare Today?", isOn: $viewModel.isFlareDay)

                Button("Save Log") {
                    viewModel.saveLog()
                }
                .buttonStyle(.borderedProminent)

                Button("DEV - Add Log") {
                    let fakeLog = DailyLog(
                        date: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
                        mood: 3,
                        painLevel: 6,
                        energyLevel: 4,
                        meals: [],
                        activities: [],
                        medicationsTaken: [],
                        notes: nil,
                        isFlareDay: false,
                        symptomRatings: [
                            SymptomRating(symptomName: "Fatigue", rating: 6),
                            SymptomRating(symptomName: "Headache", rating: 4)
                        ]
                    )
                    LogsRepo.shared.saveLog(fakeLog)
                }
            }
            .padding()
        }
        .navigationTitle("Today")
        .onAppear {
            viewModel.load()
        }
    }
}
