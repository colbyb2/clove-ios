import Foundation
import SwiftUI

@Observable
class AppState {
    enum LaunchPhase {
        case loading
        case onboarding
        case main
    }

    var phase: LaunchPhase = .loading

    func completeOnboarding() {
        phase = .main
    }

}
