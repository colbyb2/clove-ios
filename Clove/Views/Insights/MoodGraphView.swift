import SwiftUI
import Charts

struct MoodGraphView: View {
   let logs: [DailyLog]
   
   @State private var lineWidth = 2.0
   @State private var interpolationMethod: InterpolationMethod = .catmullRom
   @State private var chartColor: Color = CloveColors.primary
   @State private var showGradient = true
   @State private var gradientRange = 0.5
   
   private var gradient: Gradient {
      var colors = [chartColor]
      if showGradient {
         colors.append(chartColor.opacity(gradientRange))
      }
      return Gradient(colors: colors)
   }
   
   var body: some View {
      VStack(alignment: .leading) {
         Text("Mood Over Time")
            .font(.headline)
            .padding(.bottom, 4)
         
         chart
         .frame(height: 200)
      }
   }
   
   private var chart: some View {
      Chart(logs) { log in
         LineMark(
            x: .value("Date", log.date),
            y: .value("Mood", log.mood ?? 0)
         )
         .foregroundStyle(CloveColors.primary)
         .interpolationMethod(interpolationMethod)
         .lineStyle(StrokeStyle(lineWidth: 3))
      }
      .chartYAxis {
         AxisMarks(position: .leading)
      }
   }
}
