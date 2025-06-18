import SwiftUI
import Charts

struct MoodGraphView: View {
    let logs: [DailyLog]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Mood Over Time")
                .font(.headline)
                .padding(.bottom, 4)

            Chart {
                ForEach(logs.filter { $0.mood != nil }) { log in
                    LineMark(
                        x: .value("Date", log.date),
                        y: .value("Mood", log.mood ?? 0)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(CloveColors.primary)
                    .symbol(Circle())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 200)
        }
    }
}