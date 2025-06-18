import SwiftUI
import Charts

struct PainEnergyGraphView: View {
    let logs: [DailyLog]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Pain vs Energy")
                .font(.headline)
                .padding(.bottom, 4)

            Chart {
                ForEach(logs.filter { $0.painLevel != nil }) { log in
                    LineMark(
                        x: .value("Date", log.date),
                        y: .value("Pain", log.painLevel!)
                    )
                    .foregroundStyle(.red)
                    .interpolationMethod(.monotone)
                    .symbol(Circle())
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }

                ForEach(logs.filter { $0.energyLevel != nil }) { log in
                    LineMark(
                        x: .value("Date", log.date),
                        y: .value("Energy", log.energyLevel!)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.monotone)
                    .symbol(Circle())
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 200)
        }
    }
}
