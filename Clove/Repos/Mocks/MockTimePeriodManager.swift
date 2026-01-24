import Foundation

/// Mock implementation of TimePeriodManaging for testing and previews
class MockTimePeriodManager: TimePeriodManaging {
    var selectedPeriod: TimePeriod = .month

    init(selectedPeriod: TimePeriod = .month) {
        self.selectedPeriod = selectedPeriod
    }
}
