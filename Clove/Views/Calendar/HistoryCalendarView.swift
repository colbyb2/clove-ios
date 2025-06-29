import SwiftUI

struct HistoryCalendarView: View {
   @State private var viewModel = HistoryCalendarViewModel()
   
   var body: some View {
      VStack(spacing: 0) {
         
         // Horizontal scrollable category picker
         CategoryPickerView(
            categories: viewModel.availableCategories,
            selectedCategory: $viewModel.selectedCategory
         )
         .padding(.horizontal)
         
         CalendarView(records: viewModel.logsByDate.mapValues({ log in
            return CalendarRecord(color: getLogColor(log: log))
         }), onDaySelected: { date in
            viewModel.selectedDate = date
         })
         .background(.ultraThinMaterial)
         .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
         .padding()
         .padding(.vertical)
         .sheet(item: $viewModel.selectedDate) { date in
             if let log = viewModel.log(for: date) {
                 DailyLogDetailView(log: log)
             } else {
                 Text("No log available for this day.")
                     .padding()
             }
         }
         
         Spacer()
      }
      .navigationTitle("History")
      .onAppear {
         viewModel.loadData()
      }
   }
   
   func getLogColor(log: DailyLog) -> Color {
      switch viewModel.selectedCategory {
      case .allData:
         // Show a general indicator if any data exists
         if log.mood != nil || log.painLevel != nil || log.energyLevel != nil || !log.symptomRatings.isEmpty {
            return CloveColors.accent.opacity(0.7)
         }
         return .clear
         
      case .mood:
         if let mood = log.mood {
            switch mood {
            case 9...10: return .green
            case 7...8: return Color(hex: "90EE90") // Light green
            case 5...6: return .yellow
            case 3...4: return .orange
            case 1...2: return .red
            default: return .gray
            }
         }
         
      case .pain:
         if let pain = log.painLevel {
            switch pain {
            case 8...10: return .red
            case 5...7: return .orange
            case 3...4: return .yellow
            case 1...2: return Color(hex: "90EE90") // Light green
            case 0: return .green
            default: return .gray
            }
         }
         
      case .energy:
         if let energy = log.energyLevel {
            switch energy {
            case 8...10: return .green
            case 5...7: return Color(hex: "90EE90") // Light green
            case 3...4: return .yellow
            case 1...2: return .orange
            case 0: return .red
            default: return .gray
            }
         }
         
      case .meals:
         if !log.meals.isEmpty {
            return CloveColors.accent.opacity(0.8)
         }
         
      case .activities:
         if !log.activities.isEmpty {
            return CloveColors.accent.opacity(0.8)
         }
         
      case .medications:
         if !log.medicationsTaken.isEmpty {
            return CloveColors.accent.opacity(0.8)
         }
         
      case .symptom(let id, _):
         if let rating = log.symptomRatings.first(where: { $0.symptomId == id }) {
            switch rating.rating {
            case 8...10: return .red
            case 5...7: return .orange
            case 3...4: return .yellow
            case 1...2: return Color(hex: "90EE90") // Light green
            case 0: return .green
            default: return .gray
            }
         }
      }
      
      return .clear
   }
}

#Preview {
   NavigationView {
      HistoryCalendarView()
   }
}
