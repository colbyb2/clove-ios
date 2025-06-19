import SwiftUI

struct HistoryCalendarView: View {
   @State private var viewModel = HistoryCalendarViewModel()
   
   var body: some View {
      VStack {
         
         Picker("Color By", selection: $viewModel.colorMode) {
             Text("Mood").tag(ColorMode.Mood)
             Text("Pain").tag(ColorMode.Pain)
         }
         .pickerStyle(.segmented)
         .padding(.horizontal)
         
         CalendarView(records: viewModel.logsByDate.mapValues({ log in
            return CalendarRecord(color: getLogColor(log: log))
         }), onDaySelected: { date in
            viewModel.selectedDate = date
         })
         .background(.ultraThinMaterial)
         .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
         .padding()
         .sheet(item: $viewModel.selectedDate) { date in
             if let log = viewModel.log(for: date) {
                 DailyLogDetailView(log: log)
             } else {
                 Text("No log available for this day.")
                     .padding()
             }
         }
      }
      .navigationTitle("History")
   }
   
   func getLogColor(log: DailyLog) -> Color {
      switch viewModel.colorMode {
      case .Mood:
         if let mood = log.mood {
            switch mood {
            case 5: return .green
            case 3...4: return .yellow
            case 1...2: return .orange
            default: return .gray
            }
         }
      case .Pain:
         if let pain = log.painLevel {
            switch pain {
            case 8...10: return .red
            case 5...7: return .orange
            case 1...4: return .yellow
            default: return .gray
            }
         }
      }
      
      return .clear
   }
}
