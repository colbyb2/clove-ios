import Foundation

/// Protocol for managing tutorial flow
protocol TutorialManaging: AnyObject {
    /// The currently active tutorial
    var currentTutorial: Tutorial? { get set }

    /// Whether a tutorial is currently open
    var open: Bool { get set }

    /// The current step in the tutorial
    var currentStep: Int { get set }

    /// Start a tutorial
    /// - Parameter tutorial: The tutorial to start
    /// - Returns: Optional error if tutorial cannot start
    func startTutorial(_ tutorial: Tutorial) -> TutorialError?

    /// Reset a tutorial to the beginning
    /// - Parameter tutorial: The tutorial to reset
    /// - Returns: Optional error if tutorial cannot reset
    func resetTutorial(_ tutorial: Tutorial) -> TutorialError?

    /// Advance to the next step in the tutorial
    func nextStep()

    /// Complete the current tutorial
    func complete()
}

/// Conform TutorialManager to the protocol
extension TutorialManager: TutorialManaging {}
