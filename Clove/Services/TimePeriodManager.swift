import Foundation
import SwiftUI

// MARK: - Time Period Definitions

enum TimePeriod: String, CaseIterable, Identifiable {
    case week = "7D"
    case month = "30D" 
    case threeMonth = "3M"
    case sixMonth = "6M"
    case year = "1Y"
    case allTime = "All"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .week: return "7 Days"
        case .month: return "30 Days"
        case .threeMonth: return "3 Months"
        case .sixMonth: return "6 Months"
        case .year: return "1 Year"
        case .allTime: return "All Time"
        }
    }
    
    var shortDisplayName: String {
        switch self {
        case .week: return "7D"
        case .month: return "30D"
        case .threeMonth: return "3M"
        case .sixMonth: return "6M"
        case .year: return "1Y"
        case .allTime: return "All"
        }
    }
    
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .threeMonth: return 90
        case .sixMonth: return 180
        case .year: return 365
        case .allTime: return Int.max
        }
    }
    
    /// Get the date range for this time period
    var dateRange: DateInterval? {
        guard self != .allTime else { return nil }
        
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date())
        
        guard let startDate = calendar.date(byAdding: .day, value: -days + 1, to: endDate) else {
            return nil
        }
        
        // End date should be end of current day
        guard let actualEndDate = calendar.date(byAdding: .day, value: 1, to: endDate) else {
            return nil
        }
        
        return DateInterval(start: startDate, end: actualEndDate)
    }
    
    /// Get the date range for the previous period (for comparison)
    var previousPeriodRange: DateInterval? {
        guard self != .allTime else { return nil }
        
        let calendar = Calendar.current
        let currentEndDate = calendar.startOfDay(for: Date())
        
        // Calculate the start of the previous period
        guard let currentStartDate = calendar.date(byAdding: .day, value: -days + 1, to: currentEndDate),
              let previousEndDate = calendar.date(byAdding: .day, value: -1, to: currentStartDate),
              let previousStartDate = calendar.date(byAdding: .day, value: -days + 1, to: previousEndDate) else {
            return nil
        }
        
        // End of previous period
        guard let actualPreviousEndDate = calendar.date(byAdding: .day, value: 1, to: previousEndDate) else {
            return nil
        }
        
        return DateInterval(start: previousStartDate, end: actualPreviousEndDate)
    }
    
    /// Get aggregation level for chart display
    var aggregationLevel: AggregationLevel {
        switch self {
        case .week, .month:
            return .daily
        case .threeMonth, .sixMonth:
            return .weekly
        case .year, .allTime:
            return .monthly
        }
    }
}

enum AggregationLevel {
    case daily
    case weekly
    case monthly
}

// MARK: - Time Period Manager

@Observable
class TimePeriodManager {
    static let shared = TimePeriodManager()
    
    // MARK: - Published Properties
    
    /// Currently selected time period
    var selectedPeriod: TimePeriod {
        get {
            let rawValue = UserDefaults.standard.string(forKey: Constants.TIMEPERIOD) ?? TimePeriod.month.rawValue
            return TimePeriod(rawValue: rawValue) ?? .month
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Constants.TIMEPERIOD)
            // Clear custom range when selecting a predefined period
            if isUsingCustomRange {
                isUsingCustomRange = false
                customRange = nil
            }
        }
    }
    
    /// Custom date range for user-defined periods
    var customRange: DateInterval? {
        didSet {
            if customRange != nil && !isUsingCustomRange {
                isUsingCustomRange = true
            }
        }
    }
    
    /// Whether currently using a custom range instead of predefined period
    var isUsingCustomRange: Bool = false {
        didSet {
            if !isUsingCustomRange {
                customRange = nil
            }
        }
    }
    
    /// Whether comparison mode is enabled
    var isComparisonModeEnabled: Bool = false
    
    // MARK: - Computed Properties
    
    /// Get the current active date range
    var currentDateRange: DateInterval? {
        if isUsingCustomRange {
            return customRange
        } else {
            return selectedPeriod.dateRange
        }
    }
    
    /// Get the previous period range for comparison
    var previousPeriodRange: DateInterval? {
        guard isComparisonModeEnabled else { return nil }
        
        if isUsingCustomRange {
            return calculatePreviousPeriodForCustomRange()
        } else {
            return selectedPeriod.previousPeriodRange
        }
    }
    
    /// Get display text for current period
    var currentPeriodDisplayText: String {
        if isUsingCustomRange, let range = customRange {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "\(formatter.string(from: range.start)) - \(formatter.string(from: range.end))"
        } else {
            return selectedPeriod.displayName
        }
    }
    
    /// Get short display text for current period
    var currentPeriodShortText: String {
        if isUsingCustomRange, let range = customRange {
            let daysDifference = Calendar.current.dateComponents([.day], from: range.start, to: range.end).day ?? 0
            return "\(daysDifference)D"
        } else {
            return selectedPeriod.shortDisplayName
        }
    }
    
    /// Get current aggregation level
    var currentAggregationLevel: AggregationLevel {
        if isUsingCustomRange, let range = customRange {
            let daysDifference = Calendar.current.dateComponents([.day], from: range.start, to: range.end).day ?? 0
            
            switch daysDifference {
            case 0...31:
                return .daily
            case 32...180:
                return .weekly
            default:
                return .monthly
            }
        } else {
            return selectedPeriod.aggregationLevel
        }
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Set a custom date range
    func setCustomRange(_ range: DateInterval) {
        // Validate the range
        guard range.start < range.end else { return }
        
        // Limit maximum range to prevent performance issues (2 years)
        let maxDays: TimeInterval = 365 * 2 * 24 * 60 * 60
        guard range.duration <= maxDays else { return }
        
        customRange = range
        isUsingCustomRange = true
    }
    
    /// Set a custom range with start and end dates
    func setCustomRange(start: Date, end: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: start)
        
        // End date should include the full day
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)) else {
            return
        }
        
        let range = DateInterval(start: startOfDay, end: endOfDay)
        setCustomRange(range)
    }
    
    /// Reset to a predefined period
    func resetToDefaultPeriod() {
        isUsingCustomRange = false
        customRange = nil
        selectedPeriod = .month
    }
    
    /// Toggle comparison mode
    func toggleComparisonMode() {
        isComparisonModeEnabled.toggle()
    }
    
    /// Get the date range that should be used for data filtering
    func getDateRangeForDataFiltering() -> DateInterval? {
        return currentDateRange
    }
    
    /// Check if a date falls within the current period
    func isDateInCurrentPeriod(_ date: Date) -> Bool {
        guard let range = currentDateRange else { return true }
        return range.contains(date)
    }
    
    /// Get the earliest date that should be considered for "All Time" period
    func getEarliestRelevantDate() -> Date? {
        // This could be enhanced to check the actual earliest log date from the database
        // For now, return a reasonable default (1 year ago)
        return Calendar.current.date(byAdding: .year, value: -1, to: Date())
    }
    
    /// Get suggested time periods based on available data
    func getSuggestedPeriods(dataStartDate: Date?) -> [TimePeriod] {
        guard let startDate = dataStartDate else {
            return TimePeriod.allCases
        }
        
        let calendar = Calendar.current
        let daysSinceStart = calendar.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        
        var suggested: [TimePeriod] = []
        
        if daysSinceStart >= 7 { suggested.append(.week) }
        if daysSinceStart >= 30 { suggested.append(.month) }
        if daysSinceStart >= 90 { suggested.append(.threeMonth) }
        if daysSinceStart >= 180 { suggested.append(.sixMonth) }
        if daysSinceStart >= 365 { suggested.append(.year) }
        
        suggested.append(.allTime)
        
        return suggested
    }
    
    // MARK: - Private Methods
    
    private func calculatePreviousPeriodForCustomRange() -> DateInterval? {
        guard let currentRange = customRange else { return nil }
        
        let duration = currentRange.duration
        let previousEnd = currentRange.start
        let previousStart = previousEnd.addingTimeInterval(-duration)
        
        return DateInterval(start: previousStart, end: previousEnd)
    }
}

// MARK: - Convenience Extensions

extension TimePeriodManager {
    /// Quick access to common periods
    var isWeekSelected: Bool { selectedPeriod == .week && !isUsingCustomRange }
    var isMonthSelected: Bool { selectedPeriod == .month && !isUsingCustomRange }
    var isThreeMonthSelected: Bool { selectedPeriod == .threeMonth && !isUsingCustomRange }
    var isSixMonthSelected: Bool { selectedPeriod == .sixMonth && !isUsingCustomRange }
    var isYearSelected: Bool { selectedPeriod == .year && !isUsingCustomRange }
    var isAllTimeSelected: Bool { selectedPeriod == .allTime && !isUsingCustomRange }
}

// MARK: - Date Formatting Helpers

extension TimePeriodManager {
    /// Get appropriate date formatter for current period
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        
        switch currentAggregationLevel {
        case .daily:
            formatter.dateFormat = "MMM d"
        case .weekly:
            formatter.dateFormat = "MMM d"
        case .monthly:
            formatter.dateFormat = "MMM yyyy"
        }
        
        return formatter
    }
    
    /// Get appropriate date format style for chart axes
    var chartDateFormatStyle: Date.FormatStyle {
        switch currentAggregationLevel {
        case .daily:
            return .dateTime.month(.abbreviated).day()
        case .weekly:
            return .dateTime.month(.abbreviated).day()
        case .monthly:
            return .dateTime.month(.abbreviated).year(.twoDigits)
        }
    }
}
