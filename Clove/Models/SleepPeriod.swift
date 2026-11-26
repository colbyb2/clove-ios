import Foundation

/// One manually recorded interval, attributed to the local day of waking.
/// Actual dates and the recording time zone preserve overnight and DST duration.
struct SleepPeriod: Codable, Equatable, Sendable {
    let bedtime: Date
    let wakeTime: Date
    let timeZoneIdentifier: String

    var durationMinutes: Int { Int((wakeTime.timeIntervalSince(bedtime) / 60).rounded()) }
    var durationText: String { Self.format(minutes: durationMinutes) }
    var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? .current }

    static func format(minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }

    func timeRangeText(includeDays: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        if includeDays { formatter.setLocalizedDateFormatFromTemplate("EEEjm") }
        else { formatter.timeStyle = .short }
        return "\(formatter.string(from: bedtime)) → \(formatter.string(from: wakeTime))"
    }

    func validate(dayKey: String) throws {
        guard let zone = TimeZone(identifier: timeZoneIdentifier),
              bedtime.timeIntervalSinceReferenceDate.isFinite,
              wakeTime.timeIntervalSinceReferenceDate.isFinite,
              wakeTime > bedtime, wakeTime.timeIntervalSince(bedtime) <= 25 * 60 * 60 else {
            throw SleepEntryError.invalidInterval
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        guard LocalDayKey.make(for: wakeTime, calendar: calendar) == dayKey else {
            throw SleepEntryError.wrongDay
        }
    }

    static func fromTimes(wakeDay: Date, bedtimeHour: Int, bedtimeMinute: Int,
                          wakeHour: Int, wakeMinute: Int, timeZone: TimeZone = .current) throws -> SleepPeriod {
        guard (0...23).contains(bedtimeHour), (0...23).contains(wakeHour),
              (0...59).contains(bedtimeMinute), (0...59).contains(wakeMinute) else {
            throw SleepEntryError.invalidInterval
        }
        let bedClock = bedtimeHour * 60 + bedtimeMinute
        let wakeClock = wakeHour * 60 + wakeMinute
        guard bedClock != wakeClock else { throw SleepEntryError.sameTimes }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let day = calendar.startOfDay(for: wakeDay)
        guard let bedDay = bedClock > wakeClock ? calendar.date(byAdding: .day, value: -1, to: day) : day else {
            throw SleepEntryError.invalidInterval
        }
        func clock(_ hour: Int, _ minute: Int, on date: Date) throws -> Date {
            guard let result = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date,
                                              matchingPolicy: .strict, repeatedTimePolicy: .first),
                  calendar.isDate(result, inSameDayAs: date),
                  calendar.component(.hour, from: result) == hour,
                  calendar.component(.minute, from: result) == minute else {
                throw SleepEntryError.clockChange
            }
            return result
        }
        let period = try SleepPeriod(bedtime: clock(bedtimeHour, bedtimeMinute, on: bedDay),
                                     wakeTime: clock(wakeHour, wakeMinute, on: day),
                                     timeZoneIdentifier: timeZone.identifier)
        try period.validate(dayKey: LocalDayKey.make(for: day, calendar: calendar))
        return period
    }
}

enum SleepEntryError: LocalizedError {
    case invalidInterval, wrongDay, sameTimes, clockChange
    var errorDescription: String? {
        switch self {
        case .invalidInterval: "Choose a bedtime before your wake-up time, within one night."
        case .wrongDay: "Save sleep on the day you woke up."
        case .sameTimes: "Bedtime and wake-up time must be different."
        case .clockChange: "That time doesn’t exist on this date because the clocks changed. Choose another time."
        }
    }
}
