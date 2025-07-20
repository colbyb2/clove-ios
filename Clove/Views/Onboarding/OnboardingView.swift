import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) var appState
    @State var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
           switch viewModel.step {
           case .welcome:
               WelcomeView()
           case .moduleSelection:
               FeatureSelectionView()
           case .symptomSelection:
               SymptomSelectionView()
           case .insightsComplexity:
               InsightsComplexityOnboardingView()
           case .notifications:
               OnboardingNotificationView()
           case .colorScheme:
               ColorSchemeSelectionView()
           case .complete:
               CompleteView()
           }
        }
        .environment(viewModel)
    }
}

#Preview {
   OnboardingView()
      .environment(AppState())
}
