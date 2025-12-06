
import SwiftUI

struct CalendarView: View {
   var theme: CalendarTheme = .defaultTheme
   var records: [Date: CalendarRecord] = [:]
   var onDaySelected: (Date) -> Void = { _ in }
   
   let calendar = Calendar.current
   @State private var selectedDate = Date()
   @State private var selectedDay: Date? = nil
   @GestureState private var dragOffset: CGSize = .zero
   
   var body: some View {
      VStack(spacing: 10) {
         HStack {
            Button(action: { changeMonth(by: -1) }) {
               Image(systemName: "chevron.left")
            }
            .foregroundStyle(theme.primary)
            
            Spacer()
            
            Text(monthTitle)
               .font(.title2)
               .bold()
            
            Spacer()
            
            Button(action: { changeMonth(by: 1) }) {
               Image(systemName: "chevron.right")
            }
            .foregroundStyle(theme.primary)
         }
         .padding(.horizontal)
         
         HStack {
            ForEach(weekdays, id: \.self) { day in
               Text(day)
                  .font(.caption)
                  .frame(maxWidth: .infinity)
            }
         }
         
         LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
            ForEach(paddedDays.indices, id: \.self) { index in
               if let day = paddedDays[index] {
                  let date = dateForDay(day)
                  let isToday = calendar.isDate(date, inSameDayAs: Date())
                  let isSelected = selectedDay != nil && calendar.isDate(date, inSameDayAs: selectedDay!)
                  let record: CalendarRecord? = records[date]
                  
                  Text("\(day)")
                     .frame(maxWidth: .infinity, minHeight: 40)
                     .foregroundColor(textColor(for: record, isSelected: isSelected))
                     .background {
                        ZStack {
                           // Heatmap background
                           if let record {
                              RoundedRectangle(cornerRadius: 8)
                                 .fill(record.color)
                           }

                           // Today border
                           if isToday {
                              RoundedRectangle(cornerRadius: 8)
                                 .stroke(theme.todayBorder, lineWidth: 2)
                           }

                           // Selection indicator
                           if isSelected {
                              RoundedRectangle(cornerRadius: 8)
                                 .stroke(theme.primary, lineWidth: 2.5)
                           }
                        }
                     }
                     .onTapGesture {
                        withAnimation {
                           selectedDay = date
                        }
                        onDaySelected(date)
                     }
               } else {
                  Color.clear.frame(height: 40)
               }
            }
         }
         .gesture(
            DragGesture()
               .updating($dragOffset) { value, state, _ in
                  state = value.translation
               }
               .onEnded { value in
                  let threshold: CGFloat = 50
                  if value.translation.width < -threshold {
                     changeMonth(by: 1)
                  } else if value.translation.width > threshold {
                     changeMonth(by: -1)
                  }
               }
         )
      }
      .padding()
   }
   
   var monthTitle: String {
      let formatter = DateFormatter()
      formatter.dateFormat = "LLLL yyyy"
      return formatter.string(from: selectedDate)
   }
   
   var weekdays: [String] {
      let formatter = DateFormatter()
      formatter.locale = calendar.locale
      return formatter.shortWeekdaySymbols
   }
   
   var paddedDays: [Int?] {
      let range = calendar.range(of: .day, in: .month, for: selectedDate)!
      let components = calendar.dateComponents([.year, .month], from: selectedDate)
      let firstOfMonth = calendar.date(from: components)!
      let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
      
      let padding: [Int?] = Array(repeating: nil, count: firstWeekday - 1)
      let days = range.map { Optional($0) }
      
      return padding + days
   }
   
   func dateForDay(_ day: Int) -> Date {
      var components = calendar.dateComponents([.year, .month], from: selectedDate)
      components.day = day
      return calendar.date(from: components)!
   }
   
   func changeMonth(by value: Int) {
      if let newDate = calendar.date(byAdding: .month, value: value, to: selectedDate) {
         selectedDate = newDate
      }
   }

   func textColor(for record: CalendarRecord?, isSelected: Bool) -> Color {
      // If there's a colored heatmap background, use white text for better contrast
      if let record = record {
         // Check if the color is likely to be dark/saturated
         return .white
      }
      // For days without data, use theme colors
      return isSelected ? theme.selectedTextColor : theme.textColor
   }
}

struct CalendarTheme {
   var primary: Color          // Selected day background
   var todayBorder: Color      // Border around today
   var textColor: Color        // Day text
   var selectedTextColor: Color // Selected day text
   var eventDotColor: Color    // Event marker
}

struct CalendarRecord {
   let color: Color
}

extension CalendarTheme {
   static let defaultTheme = CalendarTheme(
      primary: Theme.shared.accent,
      todayBorder: Theme.shared.accent,
      textColor: CloveColors.primaryText,
      selectedTextColor: CloveColors.primaryText,
      eventDotColor: CloveColors.primary
   )
}

#Preview {
   CalendarView()
}
