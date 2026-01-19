import Foundation

/// Mock implementation of NavigationCoordinating for testing and previews
final class MockNavigationCoordinator: NavigationCoordinating {
    var selectedTab: Int = 0
    var targetDate: Date? = nil

    /// Tracks how many times editDayInTodayView was called
    var editDayCallCount: Int = 0

    func editDayInTodayView(date: Date) {
        targetDate = date
        selectedTab = 0
        editDayCallCount += 1
    }

    func clearTargetDate() {
        targetDate = nil
    }
}
