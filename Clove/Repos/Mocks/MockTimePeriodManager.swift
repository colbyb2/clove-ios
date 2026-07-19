import Foundation

/// Mock implementation of TimePeriodManaging for testing and previews
class MockTimePeriodManager: TimePeriodManaging {
    var selectedPeriod: TimePeriod = .month {
        didSet { customRange = nil }
    }
    var customRange: DateInterval?
    var isUsingCustomRange: Bool { customRange != nil }
    var currentDateRange: DateInterval? {
        customRange ?? selectedPeriod.dateRange
    }

    init(selectedPeriod: TimePeriod = .month) {
        self.selectedPeriod = selectedPeriod
    }

    func setCustomRange(_ range: DateInterval) {
        customRange = range
    }
}
