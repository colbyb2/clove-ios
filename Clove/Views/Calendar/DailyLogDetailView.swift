import SwiftUI

struct DailyLogDetailView: View {
    let log: DailyLog

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Log for \(log.date.formatted(date: .abbreviated, time: .omitted))")
                .font(.headline)

            if let mood = log.mood {
                Text("Mood: \(mood)/5")
            }

            if let pain = log.painLevel {
                Text("Pain: \(pain)/10")
            }

            if let energy = log.energyLevel {
                Text("Energy: \(energy)/10")
            }

            if !log.symptomRatings.isEmpty {
                Text("Symptoms:")
                    .bold()
                ForEach(log.symptomRatings, id: \.symptomName) { symptom in
                    Text("- \(symptom.symptomName): \(symptom.rating)")
                }
            }

            if let notes = log.notes {
                Text("Notes: \(notes)")
                    .italic()
            }

            Spacer()
        }
        .padding()
        .presentationDetents([.medium, .large])
    }
}
