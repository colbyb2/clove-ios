import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: OnboardingViewModel?

    var body: some View {
        ZStack {
            if let viewModel = viewModel {
                OnboardingContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = OnboardingViewModel(
                    symptomsRepository: dependencies.symptomsRepository,
                    settingsRepository: dependencies.settingsRepository
                )
            }
        }
    }
}

private struct OnboardingContent: View {
    @Bindable var viewModel: OnboardingViewModel

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
        .environment(\.dependencies, MockDependencyContainer())
}
