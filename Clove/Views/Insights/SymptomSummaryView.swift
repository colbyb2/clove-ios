import SwiftUI
import Charts

struct SymptomSummaryView: View {
   let logs: [DailyLog]
   
   // State for the currently selected symptom
   @State private var selectedSymptom: String?
   
   // Computed property to get all unique, available symptoms from logs
   private var availableSymptoms: [String] {
      let allRatings = logs.flatMap { $0.symptomRatings }
      return Array(Set(allRatings.map { $0.symptomName })).sorted()
   }
   
   // Computed property to get the chart data for the selected symptom
   private var chartData: [SymptomDataPoint] {
      guard let selectedSymptom = selectedSymptom else { return [] }
      
      return logs.compactMap { log -> SymptomDataPoint? in
         if let rating = log.symptomRatings.first(where: { $0.symptomName == selectedSymptom }) {
            return SymptomDataPoint(date: log.date, rating: rating.rating)
         }
         return nil
      }.sorted(by: { $0.date < $1.date })
   }
   
   var body: some View {
      VStack(alignment: .leading, spacing: 16) {
         // Dropdown menu for symptom selection
         symptomSelector
         
         // Show chart if a symptom is selected, otherwise show an empty state
         if selectedSymptom != nil {
            symptomChart
         } else {
            emptyStateView
         }
      }
      .padding(.top, 8)
      .onAppear {
         if selectedSymptom == nil {
            selectedSymptom = availableSymptoms.first
         }
      }
   }
   
   // Dropdown menu for selecting a symptom
   private var symptomSelector: some View {
      Menu {
         ForEach(availableSymptoms, id: \.self) { symptom in
            Button(action: {
               selectedSymptom = symptom
            }) {
               Text(symptom)
            }
         }
      } label: {
         HStack {
            Text(selectedSymptom ?? "Select a Symptom")
               .font(.headline)
               .foregroundStyle(CloveColors.primary)
            Image(systemName: "chevron.down")
               .font(.caption.weight(.bold))
               .foregroundStyle(CloveColors.secondaryText)
         }
      }
   }
   
   // Chart view for the selected symptom
   private var symptomChart: some View {
      Chart(chartData) { dataPoint in
         LineMark(
            x: .value("Date", dataPoint.date),
            y: .value("Rating", dataPoint.rating)
         )
         .foregroundStyle(CloveColors.accent)
         .interpolationMethod(.catmullRom)
         .lineStyle(StrokeStyle(lineWidth: 3))
      }
      .chartYScale(domain: 0...10)
      .chartYAxis {
         AxisMarks(position: .leading, values: .automatic(desiredCount: 6))
      }
      .chartXAxis {
         AxisMarks(values: .stride(by: .day, count: 2)) { value in
            AxisGridLine()
            AxisValueLabel(format: .dateTime.month().day())
         }
      }
      .frame(height: 200)
   }
   
   // View to show when no data is available
   private var emptyStateView: some View {
      HStack {
         Spacer()
         VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle")
               .font(.largeTitle)
               .foregroundStyle(CloveColors.secondaryText)
            Text("No symptom data yet.")
               .foregroundColor(.secondary)
               .italic()
         }
         Spacer()
      }
      .frame(height: 200)
   }
}

// Data structure for the symptom chart
private struct SymptomDataPoint: Identifiable {
   let id = UUID()
   let date: Date
   let rating: Int
}

#Preview {
   SymptomSummaryView(logs: [])
      .padding()
}
