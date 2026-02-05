
import SwiftUI

struct CalendarView: View {
    var theme: CalendarTheme = .defaultTheme
    var records: [Date: CalendarRecord] = [:]
    var onDaySelected: (Date) -> Void = { _ in }
    @Binding var selectedDate: Date
    
    let calendar = Calendar.current
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
                        
                        ZStack {
                            Text("\(day)")
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .foregroundColor(textColor(for: record, isSelected: isSelected))
                                .background {
                                    ZStack {
                                        // Prediction background (shown behind everything)
                                        if let record, record.isPredictedCycle {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.pink.opacity(0.2))
                                        }

                                        // Heatmap background
                                        if let record, !record.isPredictedCycle {
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

                            // Cycle indicator emoji
                            if let record, record.hasCycleEntry {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Image(systemName: "drop.fill")
                                            .font(.system(size: 10))
                                            .padding([.trailing, .bottom], 2)
                                            .foregroundStyle(Color.pink)
                                    }
                                }
                            }

                            // Prediction indicator
                            if let record, record.isPredictedCycle {
                                VStack {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "drop")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundStyle(Color.pink.opacity(0.6))
                                            .padding([.trailing, .top], 3)
                                    }
                                    Spacer()
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
        if record != nil {
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
    var icon: String?
    var hasCycleEntry: Bool = false
    var isPredictedCycle: Bool = false
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

#Preview("Empty") {
    struct PreviewWrapper: View {
        @State private var selectedDate = Date()
        
        var body: some View {
            CalendarView(selectedDate: $selectedDate)
        }
    }
    
    return PreviewWrapper()
}

#Preview("Cycle Data") {
    struct PreviewWrapper: View {
        @State private var selectedDate = Date()

        var records: [Date: CalendarRecord] {
            let calendar = Calendar.current
            var recordsDict: [Date: CalendarRecord] = [:]

            // Add some regular log data (past days)
            for dayOffset in -15...(-1) {
                if let date = calendar.date(byAdding: .day, value: dayOffset, to: Date()) {
                    let normalizedDate = calendar.startOfDay(for: date)
                    // Every few days has some data
                    if dayOffset % 3 == 0 {
                        recordsDict[normalizedDate] = CalendarRecord(
                            color: CloveColors.blue.opacity(0.6),
                            icon: nil,
                            hasCycleEntry: false,
                            isPredictedCycle: false
                        )
                    }
                }
            }

            // Add actual cycle entries (3 days, starting 10 days ago)
            for dayOffset in -10...(-8) {
                if let date = calendar.date(byAdding: .day, value: dayOffset, to: Date()) {
                    let normalizedDate = calendar.startOfDay(for: date)
                    recordsDict[normalizedDate] = CalendarRecord(
                        color: .clear,
                        icon: nil,
                        hasCycleEntry: true,
                        isPredictedCycle: false
                    )
                }
            }

            // Add predicted cycle entries (5 days, starting 5 days from now)
            for dayOffset in 5...9 {
                if let date = calendar.date(byAdding: .day, value: dayOffset, to: Date()) {
                    let normalizedDate = calendar.startOfDay(for: date)
                    recordsDict[normalizedDate] = CalendarRecord(
                        color: .clear,
                        icon: nil,
                        hasCycleEntry: false,
                        isPredictedCycle: true
                    )
                }
            }

            // Today has some data
            let today = calendar.startOfDay(for: Date())
            recordsDict[today] = CalendarRecord(
                color: CloveColors.green.opacity(0.7),
                icon: nil,
                hasCycleEntry: false,
                isPredictedCycle: false
            )

            return recordsDict
        }

        var body: some View {
            CalendarView(
                records: records,
                selectedDate: $selectedDate
            )
            .padding()
        }
    }

    return PreviewWrapper()
}
