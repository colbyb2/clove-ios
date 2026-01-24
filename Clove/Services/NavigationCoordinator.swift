import SwiftUI

/// Coordinates navigation between different tabs and views
@Observable
class NavigationCoordinator {
    static let shared = NavigationCoordinator()

    /// Currently selected tab index
    var selectedTab: Int = 0

    /// Date to navigate to in TodayView
    var targetDate: Date?

    init() {}
    
    /// Navigate to the Today tab and set a specific date for editing
    func editDayInTodayView(date: Date) {
        targetDate = date
        selectedTab = 0 // Today tab index
    }
    
    /// Clear the target date (called when TodayView loads the target date)
    func clearTargetDate() {
        targetDate = nil
    }
}
