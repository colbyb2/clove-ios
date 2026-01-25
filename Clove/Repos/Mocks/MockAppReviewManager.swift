import Foundation

/// Mock implementation of AppReviewManaging for testing and previews
final class MockAppReviewManager: AppReviewManaging {
    /// Tracks how many times trackAppLaunch was called
    var trackAppLaunchCallCount: Int = 0

    /// Tracks how many times promptForReviewIfEligible was called
    var promptCallCount: Int = 0

    /// Tracks how many times recordUserRated was called
    var recordUserRatedCallCount: Int = 0

    /// Tracks how many times resetReviewState was called
    var resetCallCount: Int = 0

    /// Set this to true to simulate the prompt being shown
    var shouldShowPrompt: Bool = false

    func trackAppLaunch() {
        trackAppLaunchCallCount += 1
    }

    func promptForReviewIfEligible() async {
        promptCallCount += 1
        // In a real test, you might want to verify this was called
        // but not actually trigger the system review prompt
    }

    func recordUserRated() {
        recordUserRatedCallCount += 1
    }

    func resetReviewState() {
        resetCallCount += 1
    }
}
