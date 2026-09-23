import SwiftUI

struct CalendarView: View {
    var theme: CalendarTheme = .defaultTheme
    var records: [Date: CalendarRecord] = [:]
    var onDaySelected: (Date) -> Void = { _ in }
    @Binding var selectedDate: Date
    @Binding var selectedDay: Date?
    var showsCycleOverlay: Bool = true

    private let calendar = Calendar.current
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        theme: CalendarTheme = .defaultTheme,
        records: [Date: CalendarRecord] = [:],
        onDaySelected: @escaping (Date) -> Void = { _ in },
        selectedDate: Binding<Date>,
        selectedDay: Binding<Date?> = .constant(nil),
        showsCycleOverlay: Bool = true
    ) {
        self.theme = theme
        self.records = records
        self.onDaySelected = onDaySelected
        _selectedDate = selectedDate
        _selectedDay = selectedDay
        self.showsCycleOverlay = showsCycleOverlay
    }

    var body: some View {
        VStack(spacing: 10) {
            monthHeader
            weekdayHeader

            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(calendarDays) { day in
                    dayCell(day)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.large)
                .fill(CloveColors.card)
                .overlay {
                    RoundedRectangle(cornerRadius: CloveCorners.large)
                        .stroke(CloveColors.secondaryText.opacity(0.12), lineWidth: 1)
                }
        )
        .contentShape(Rectangle())
        .gesture(monthSwipe)
    }

    private var monthHeader: some View {
        HStack(spacing: CloveSpacing.small) {
            monthButton(systemName: "chevron.left", offset: -1, label: "Previous month")
            Spacer()
            Text(monthTitle)
                .font(CloveFonts.title())
                .foregroundStyle(CloveColors.primaryText)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            monthButton(systemName: "chevron.right", offset: 1, label: "Next month")
        }
    }

    private func monthButton(systemName: String, offset: Int, label: String) -> some View {
        Button { changeMonth(by: offset) } label: {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.shared.accent)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Theme.shared.accent.opacity(0.09)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(orderedWeekdays, id: \.self) { day in
                Text(day)
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(CloveColors.secondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayCell(_ day: CalendarDay) -> some View {
        let normalizedDate = calendar.startOfDay(for: day.date)
        let record = records[normalizedDate]
        let isToday = calendar.isDateInToday(day.date)
        let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: day.date) } ?? false
        let hasHeatmapColor = record.map { $0.color != .clear } ?? false

        return Button {
            if !day.isInDisplayedMonth { selectedDate = day.date }
            selectedDay = normalizedDate
            onDaySelected(normalizedDate)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: CloveCorners.small)
                    .fill(cellBackground(record: record, hasHeatmapColor: hasHeatmapColor))
                RoundedRectangle(cornerRadius: CloveCorners.small)
                    .strokeBorder(
                        isSelected ? Theme.shared.accent : (isToday ? Theme.shared.accent.opacity(0.55) : Color.clear),
                        lineWidth: isSelected ? 2.5 : 1.5
                    )

                VStack(spacing: 2) {
                    Text(day.date.formatted(.dateTime.day()))
                        .font(.system(.body, design: .rounded, weight: isSelected || isToday ? .bold : .medium))
                        .foregroundStyle(dayTextColor(isInDisplayedMonth: day.isInDisplayedMonth, hasHeatmapColor: hasHeatmapColor))

                    if let value = record?.valueLabel, day.isInDisplayedMonth {
                        Text(value)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(hasHeatmapColor ? Color.white.opacity(0.9) : Theme.shared.accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    } else if record?.hasData == true, day.isInDisplayedMonth {
                        Circle().fill(Theme.shared.accent).frame(width: 5, height: 5)
                    }
                }

                if day.isInDisplayedMonth { calendarMarkers(record) }
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .opacity(day.isInDisplayedMonth ? 1 : 0.34)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: day.date, record: record, isToday: isToday))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private func calendarMarkers(_ record: CalendarRecord?) -> some View {
        if let record {
            VStack {
                HStack {
                    if record.isFlareDay {
                        Circle().fill(CloveColors.orange).frame(width: 7, height: 7).padding(4)
                    }
                    Spacer()
                    if showsCycleOverlay && record.isPredictedCycle {
                        Image(systemName: "drop")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.pink.opacity(0.8))
                            .padding(4)
                    }
                }
                Spacer()
                if showsCycleOverlay && record.hasCycleEntry {
                    HStack {
                        Spacer()
                        Image(systemName: "drop.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.pink)
                            .padding(4)
                    }
                }
            }
        }
    }

    private func cellBackground(record: CalendarRecord?, hasHeatmapColor: Bool) -> Color {
        if hasHeatmapColor, let record { return record.color }
        if showsCycleOverlay, record?.isPredictedCycle == true { return Color.pink.opacity(0.08) }
        return CloveColors.background.opacity(0.42)
    }

    private func dayTextColor(isInDisplayedMonth: Bool, hasHeatmapColor: Bool) -> Color {
        if hasHeatmapColor { return .white }
        return isInDisplayedMonth ? CloveColors.primaryText : CloveColors.secondaryText
    }

    private func accessibilityLabel(for date: Date, record: CalendarRecord?, isToday: Bool) -> String {
        var parts = [date.formatted(date: .complete, time: .omitted)]
        if isToday { parts.append("Today") }
        if let value = record?.accessibilityValue { parts.append(value) }
        else if record?.hasData == true { parts.append("Data recorded") }
        if record?.isFlareDay == true { parts.append("Flare day") }
        if showsCycleOverlay && record?.hasCycleEntry == true { parts.append("Period recorded") }
        if showsCycleOverlay && record?.isPredictedCycle == true { parts.append("Predicted period") }
        return parts.joined(separator: ", ")
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
    }

    private var monthTitle: String { selectedDate.formatted(.dateTime.month(.wide).year()) }

    private var orderedWeekdays: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[start...] + symbols[..<start])
    }

    private var calendarDays: [CalendarDay] {
        let components = calendar.dateComponents([.year, .month], from: selectedDate)
        guard let firstOfMonth = calendar.date(from: components) else { return [] }
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingDays = (weekday - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -leadingDays, to: firstOfMonth) else { return [] }

        return (0..<42).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: gridStart) else { return nil }
            return CalendarDay(date: date, isInDisplayedMonth: calendar.isDate(date, equalTo: selectedDate, toGranularity: .month))
        }
    }

    private var monthSwipe: some Gesture {
        DragGesture(minimumDistance: 24).onEnded { value in
            guard abs(value.translation.width) > abs(value.translation.height), abs(value.translation.width) > 50 else { return }
            changeMonth(by: value.translation.width < 0 ? 1 : -1)
        }
    }

    private func changeMonth(by value: Int) {
        guard let newDate = calendar.date(byAdding: .month, value: value, to: selectedDate) else { return }
        if reduceMotion { selectedDate = newDate }
        else { withAnimation(.easeInOut(duration: 0.2)) { selectedDate = newDate } }
        selectedDay = nil
    }
}

private struct CalendarDay: Identifiable {
    let date: Date
    let isInDisplayedMonth: Bool
    var id: Date { date }
}

struct CalendarTheme {
    var primary: Color
    var todayBorder: Color
    var textColor: Color
    var selectedTextColor: Color
    var eventDotColor: Color
}

struct CalendarRecord {
    let color: Color
    var icon: String? = nil
    var hasCycleEntry: Bool = false
    var isPredictedCycle: Bool = false
    var hasData: Bool = false
    var isFlareDay: Bool = false
    var valueLabel: String? = nil
    var accessibilityValue: String? = nil
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

#Preview("Calendar") {
    struct PreviewWrapper: View {
        @State private var month = Date()
        @State private var day: Date? = Date()

        var body: some View {
            CalendarView(
                records: [Calendar.current.startOfDay(for: Date()): CalendarRecord(
                    color: Theme.shared.accent.opacity(0.75),
                    hasData: true,
                    valueLabel: "7",
                    accessibilityValue: "Mood 7 out of 10"
                )],
                selectedDate: $month,
                selectedDay: $day
            )
            .padding()
            .background(CloveColors.background)
        }
    }
    return PreviewWrapper()
}
