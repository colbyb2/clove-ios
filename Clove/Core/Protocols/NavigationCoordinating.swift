import Foundation

/// Protocol for coordinating navigation between tabs and views
protocol NavigationCoordinating: AnyObject {
    /// Currently selected tab index
    var selectedTab: Int { get set }

    /// Date to navigate to in TodayView
    var targetDate: Date? { get set }

    /// Navigate to the Today tab and set a specific date for editing
    /// - Parameter date: The date to navigate to
    func editDayInTodayView(date: Date)

    /// Clear the target date (called when TodayView loads the target date)
    func clearTargetDate()
}

/// Conform NavigationCoordinator to the protocol
extension NavigationCoordinator: NavigationCoordinating {}
