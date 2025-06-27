import SwiftUI
import Charts
import Foundation

struct SymptomSummaryView: View {
   let logs: [DailyLog]
   
   // State for the currently selected symptom
   @State private var selectedSymptomId: Int64?
   
   // Get all tracked symptoms for reference
   private var trackedSymptoms: [TrackedSymptom] {
      SymptomsRepo.shared.getTrackedSymptoms()
   }
   
   // Computed property to get all unique, available symptoms from logs
   private var availableSymptoms: [TrackedSymptom] {
      let allRatings = logs.flatMap { $0.symptomRatings }
      let symptomIds = Set(allRatings.map { $0.symptomId })
      
      return trackedSymptoms.filter { symptom in
         guard let id = symptom.id else { return false }
         return symptomIds.contains(id)
      }.sorted { $0.name < $1.name }
   }
   
   // Helper to get symptom name by ID
   private func getSymptomName(for id: Int64) -> String {
      return trackedSymptoms.first { $0.id == id }?.name ?? "Unknown Symptom"
   }
   
   // Computed property to get the chart data for the selected symptom
   private var chartData: [SymptomDataPoint] {
      guard let selectedSymptomId = selectedSymptomId else { return [] }
      
      return logs.compactMap { log -> SymptomDataPoint? in
         if let rating = log.symptomRatings.first(where: { $0.symptomId == selectedSymptomId }) {
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
         if selectedSymptomId != nil {
            symptomChart
         } else {
            emptyStateView
         }
      }
      .padding(.top, 8)
      .onAppear {
         if selectedSymptomId == nil {
            selectedSymptomId = availableSymptoms.first?.id
         }
      }
   }
   
   // Dropdown menu for selecting a symptom
   private var symptomSelector: some View {
      Menu {
         ForEach(availableSymptoms, id: \.id) { symptom in
            Button(action: {
               selectedSymptomId = symptom.id
            }) {
               Text(symptom.name)
            }
         }
      } label: {
         HStack {
            Text(selectedSymptomId != nil ? getSymptomName(for: selectedSymptomId!) : "Select a Symptom")
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
