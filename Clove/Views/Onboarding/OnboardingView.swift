import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: OnboardingViewModel?

    var body: some View {
        ZStack {
            CloveColors.background.ignoresSafeArea()

            if let viewModel {
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.progressText != nil {
                OnboardingProgressHeader(viewModel: viewModel)
            }

            Group {
                switch viewModel.step {
                case .welcome:
                    CloveIntroView()
                case .valueOverview:
                    WelcomeView()
                case .moduleSelection:
                    FeatureSelectionView()
                case .symptomSelection:
                    SymptomSelectionView()
                case .notifications:
                    OnboardingNotificationView()
                case .colorScheme:
                    ColorSchemeSelectionView()
                case .terms:
                    OnboardingTermsView()
                case .complete:
                    CompleteView()
                }
            }
            .id(viewModel.step)
            .transition(reduceMotion ? .opacity : .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.42, dampingFraction: 0.88), value: viewModel.step)
        .environment(viewModel)
    }
}

private struct OnboardingProgressHeader: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        HStack(spacing: 14) {
            Button(action: viewModel.previousStep) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(CloveColors.primaryText)
                    .frame(width: 40, height: 40)
                    .background(CloveColors.card, in: Circle())
                    .overlay(Circle().stroke(CloveColors.secondaryText.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(viewModel.progressText ?? "")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CloveColors.secondaryText)
                    Spacer()
                    Text("Clove setup")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.shared.accent)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(CloveColors.secondaryText.opacity(0.13))
                        Capsule()
                            .fill(Theme.shared.accent)
                            .frame(width: proxy.size.width * viewModel.progress)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(.horizontal, CloveSpacing.medium)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(CloveColors.background)
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
        .environment(\.dependencies, MockDependencyContainer())
}
