import Foundation

@Observable
class AppState {
    enum LaunchPhase {
        case loading
        case onboarding
        case main
    }

    var phase: LaunchPhase = .main

    func completeOnboarding() {
        phase = .main
    }

}