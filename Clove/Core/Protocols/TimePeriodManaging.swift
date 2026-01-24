import Foundation

/// Protocol for time period management operations used by ViewModels
protocol TimePeriodManaging: AnyObject {
    /// Currently selected time period
    var selectedPeriod: TimePeriod { get set }
}

/// Conform TimePeriodManager to the protocol
extension TimePeriodManager: TimePeriodManaging {}
