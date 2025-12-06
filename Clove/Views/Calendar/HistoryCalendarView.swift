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
      .background(CloveColors.background)
      .navigationTitle("History")
      .onAppear {
         viewModel.loadData()
         if TutorialManager.shared.startTutorial(Tutorials.CalendarView) == .Failure {
            print("Tutorial [CalendarView] Failed to Start")
         }
      }
   }
   
   func getLogColor(log: DailyLog) -> Color {
      switch viewModel.selectedCategory {
      case .allData:
         // Show a general indicator if any data exists
         if log.mood != nil || log.painLevel != nil || log.energyLevel != nil || !log.symptomRatings.isEmpty {
            return Theme.shared.accent.opacity(0.5)
         }
         return .clear
         
      case .mood:
         if let mood = log.mood {
            switch mood {
            case 9...10: return CloveColors.green.opacity(0.6)
            case 7...8: return CloveColors.blue.opacity(0.55)
            case 5...6: return CloveColors.yellow.opacity(0.5)
            case 3...4: return CloveColors.orange.opacity(0.65)
            case 1...2: return CloveColors.red.opacity(0.7)
            default: return .gray.opacity(0.3)
            }
         }
         
      case .pain:
         if let pain = log.painLevel {
            switch pain {
            case 8...10: return CloveColors.red.opacity(0.75)
            case 5...7: return CloveColors.orange.opacity(0.65)
            case 3...4: return CloveColors.yellow.opacity(0.5)
            case 1...2: return CloveColors.blue.opacity(0.45)
            case 0: return CloveColors.green.opacity(0.4)
            default: return .gray.opacity(0.3)
            }
         }
         
      case .energy:
         if let energy = log.energyLevel {
            switch energy {
            case 8...10: return CloveColors.green.opacity(0.6)
            case 5...7: return CloveColors.blue.opacity(0.55)
            case 3...4: return CloveColors.yellow.opacity(0.5)
            case 1...2: return CloveColors.orange.opacity(0.65)
            case 0: return CloveColors.red.opacity(0.7)
            default: return .gray.opacity(0.3)
            }
         }
         
      case .meals:
         if !log.meals.isEmpty {
            return Theme.shared.accent.opacity(0.6)
         }

      case .activities:
         if !log.activities.isEmpty {
            return Theme.shared.accent.opacity(0.6)
         }

      case .medications:
         if !log.medicationsTaken.isEmpty {
            return Theme.shared.accent.opacity(0.6)
         }
         
      case .symptom(let id, _):
         if let rating = log.symptomRatings.first(where: { $0.symptomId == id }) {
            switch rating.rating {
            case 8...10: return CloveColors.red.opacity(0.75)
            case 5...7: return CloveColors.orange.opacity(0.65)
            case 3...4: return CloveColors.yellow.opacity(0.5)
            case 1...2: return CloveColors.blue.opacity(0.45)
            case 0: return CloveColors.green.opacity(0.4)
            default: return .gray.opacity(0.3)
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
