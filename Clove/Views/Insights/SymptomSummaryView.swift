import SwiftUI

struct SymptomSummaryView: View {
    let logs: [DailyLog]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Symptom Averages")
                .font(.headline)

            ForEach(symptomAverages.sorted(by: { $0.value > $1.value }), id: \.key) { symptom, average in
                HStack {
                    Text(symptom)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(format: "%.1f", average))
                        .foregroundColor(.gray)
                }
            }

            if symptomAverages.isEmpty {
                Text("No symptom data yet.")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(.top, 8)
    }

    private var symptomAverages: [String: Double] {
        var ratings: [String: [Int]] = [:]

        for log in logs {
            for rating in log.symptomRatings {
                ratings[rating.symptomName, default: []].append(rating.rating)
            }
        }

        return ratings.mapValues { vals in
            guard !vals.isEmpty else { return 0 }
            return Double(vals.reduce(0, +)) / Double(vals.count)
        }
    }
}
