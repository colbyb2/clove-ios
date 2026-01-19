import Foundation

/// Mock implementation of TutorialManaging for testing and previews
final class MockTutorialManager: TutorialManaging {
    var currentTutorial: Tutorial? = nil
    var open: Bool = false
    var currentStep: Int = 0

    /// Tracks how many times startTutorial was called
    var startCallCount: Int = 0

    func startTutorial(_ tutorial: Tutorial) -> TutorialError? {
        startCallCount += 1
        currentTutorial = tutorial
        currentStep = 0
        open = true
        return nil
    }

    func resetTutorial(_ tutorial: Tutorial) -> TutorialError? {
        currentTutorial = tutorial
        currentStep = 0
        open = true
        return nil
    }

    func nextStep() {
        guard let tutorial = currentTutorial else { return }
        let nextStep = currentStep + 1
        if nextStep < tutorial.steps.count {
            currentStep = nextStep
        } else {
            complete()
        }
    }

    func complete() {
        open = false
        currentTutorial = nil
    }
}
