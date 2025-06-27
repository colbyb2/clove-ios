import SwiftUI
import Charts

struct PainEnergyGraphView: View {
    let logs: [DailyLog]
    
    // Sort logs by date for consistent line rendering
    private var sortedLogs: [DailyLog] {
        logs.sorted(by: { $0.date < $1.date })
    }
    
    // Prepare data for pain and energy separately
    private var painData: [ChartDataPoint] {
        sortedLogs.compactMap { log in
            guard let painLevel = log.painLevel else { return nil }
            return ChartDataPoint(date: log.date, value: Double(painLevel), type: "Pain")
        }
    }
    
    private var energyData: [ChartDataPoint] {
        sortedLogs.compactMap { log in
            guard let energyLevel = log.energyLevel else { return nil }
            return ChartDataPoint(date: log.date, value: Double(energyLevel), type: "Energy")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pain vs Energy")
                .font(.headline)
                .padding(.bottom, 4)

            Chart {
                // Create a separate ForEach for each series with explicit series parameter
                ForEach(painData) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Pain", dataPoint.value)
                    )
                    .foregroundStyle(by: .value("Series", "Pain"))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .accessibilityLabel("Pain level on \(dataPoint.date.formatted(date: .abbreviated, time: .omitted))")
                    .accessibilityValue("\(Int(dataPoint.value))")
                }
                
                // Completely separate series for energy data
                ForEach(energyData) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Energy", dataPoint.value)
                    )
                    .foregroundStyle(by: .value("Series", "Energy"))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .accessibilityLabel("Energy level on \(dataPoint.date.formatted(date: .abbreviated, time: .omitted))")
                    .accessibilityValue("\(Int(dataPoint.value))")
                }
            }
            .chartForegroundStyleScale([
                "Pain": Color.red,
                "Energy": Color.blue
            ])
            .chartLegend(position: .top, alignment: .center, spacing: 20)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 2)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month().day())
                }
            }
            .frame(height: 200)
            .padding(.vertical, 8)
            .chartYScale(domain: 0...10)
        }
        .padding(.horizontal, 4)
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }
}

// Data structure for chart points
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let type: String
}

#Preview {
    PainEnergyGraphView(logs: [])
        .padding()
}
