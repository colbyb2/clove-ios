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
            return Theme.shared.accent.opacity(0.7)
         }
         return .clear
         
      case .mood:
         if let mood = log.mood {
            switch mood {
            // Best mood: Vibrant emerald green
            case 9...10: return Color(red: 0.2, green: 0.78, blue: 0.55).opacity(0.9)
            // Good mood: Fresh teal
            case 7...8: return Color(red: 0.3, green: 0.72, blue: 0.65).opacity(0.85)
            // Neutral mood: Warm amber
            case 5...6: return Color(red: 1.0, green: 0.75, blue: 0.3).opacity(0.8)
            // Poor mood: Coral orange
            case 3...4: return Color(red: 0.95, green: 0.5, blue: 0.3).opacity(0.85)
            // Worst mood: Deep rose red
            case 1...2: return Color(red: 0.85, green: 0.25, blue: 0.35).opacity(0.9)
            default: return .gray.opacity(0.5)
            }
         }
         
      case .pain:
         if let pain = log.painLevel {
            switch pain {
            // Severe pain: Intense crimson red
            case 8...10: return Color(red: 0.9, green: 0.2, blue: 0.25).opacity(0.92)
            // Moderate pain: Vibrant orange
            case 5...7: return Color(red: 0.95, green: 0.52, blue: 0.2).opacity(0.88)
            // Mild pain: Soft peach-yellow
            case 3...4: return Color(red: 1.0, green: 0.8, blue: 0.4).opacity(0.75)
            // Minimal pain: Cool mint green
            case 1...2: return Color(red: 0.4, green: 0.85, blue: 0.65).opacity(0.7)
            // No pain: Serene aqua blue
            case 0: return Color(red: 0.35, green: 0.75, blue: 0.85).opacity(0.65)
            default: return .gray.opacity(0.5)
            }
         }
         
      case .energy:
         if let energy = log.energyLevel {
            switch energy {
            // High energy: Radiant golden yellow
            case 8...10: return Color(red: 1.0, green: 0.85, blue: 0.2).opacity(0.9)
            // Good energy: Bright sky blue
            case 5...7: return Color(red: 0.25, green: 0.7, blue: 0.95).opacity(0.85)
            // Low energy: Soft lavender
            case 3...4: return Color(red: 0.65, green: 0.6, blue: 0.85).opacity(0.75)
            // Very low energy: Muted slate blue
            case 1...2: return Color(red: 0.5, green: 0.5, blue: 0.7).opacity(0.7)
            // Exhausted: Deep indigo
            case 0: return Color(red: 0.35, green: 0.35, blue: 0.55).opacity(0.85)
            default: return .gray.opacity(0.5)
            }
         }
         
      case .meals:
         if !log.meals.isEmpty {
            return Theme.shared.accent.opacity(0.75)
         }

      case .activities:
         if !log.activities.isEmpty {
            return Theme.shared.accent.opacity(0.75)
         }

      case .medications:
         if !log.medicationsTaken.isEmpty {
            return Theme.shared.accent.opacity(0.75)
         }
         
      case .symptom(let id, _):
         if let rating = log.symptomRatings.first(where: { $0.symptomId == id }) {
            // Check if this is a binary symptom
            if let symptom = viewModel.trackedSymptoms.first(where: { $0.id == id }), symptom.isBinary {
               // Binary symptom: simple yes/no coloring
               if rating.rating >= 5 {
                  // Present/Yes: Bold scarlet red
                  return Color(red: 0.92, green: 0.22, blue: 0.22).opacity(0.9)
               } else {
                  // Absent/No: Fresh spring green
                  return Color(red: 0.35, green: 0.85, blue: 0.5).opacity(0.7)
               }
            } else {
               // Non-binary symptom: full gradient
               switch rating.rating {
               // Severe symptom: Bold scarlet red
               case 8...10: return Color(red: 0.92, green: 0.22, blue: 0.22).opacity(0.92)
               // Moderate symptom: Warm tangerine
               case 5...7: return Color(red: 1.0, green: 0.6, blue: 0.25).opacity(0.88)
               // Mild symptom: Gentle gold
               case 3...4: return Color(red: 1.0, green: 0.85, blue: 0.35).opacity(0.75)
               // Minimal symptom: Seafoam teal
               case 1...2: return Color(red: 0.3, green: 0.78, blue: 0.7).opacity(0.7)
               // No symptom: Fresh spring green
               case 0: return Color(red: 0.35, green: 0.85, blue: 0.5).opacity(0.65)
               default: return .gray.opacity(0.5)
               }
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
