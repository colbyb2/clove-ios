import Foundation

enum CalendarEventTime {
    static func currentTime(
        on selectedDay: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        let day = calendar.dateComponents([.era, .year, .month, .day], from: selectedDay)
        let time = calendar.dateComponents([.hour, .minute, .second], from: now)
        var combined = DateComponents()
        combined.calendar = calendar
        combined.timeZone = calendar.timeZone
        combined.era = day.era
        combined.year = day.year
        combined.month = day.month
        combined.day = day.day
        combined.hour = time.hour
        combined.minute = time.minute
        combined.second = time.second
        return calendar.date(from: combined) ?? calendar.startOfDay(for: selectedDay)
    }
}
