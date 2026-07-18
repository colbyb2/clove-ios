//
//  CloveApp.swift
//  Clove
//
//  Created by Colby Brown on 6/17/25.
//

import SwiftUI
import CoreLocation

@main
struct CloveApp: App {
    @AppStorage(Constants.ONBOARDING_FLAG) var onboardingCompleted: Bool = false
    @AppStorage(Constants.SELECTED_COLOR) var selectedColor = ""
    @State private var appState = AppState()
    @State private var analyticsRollout = AnalyticsRolloutCoordinator.shared

    /// The dependency container for the app
    private let container = DependencyContainer.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                CloveColors.background
                    .ignoresSafeArea()

                if analyticsRollout.state == .failed {
                    AnalyticsMigrationRecoveryView(rollout: analyticsRollout, databaseManager: container.databaseManager)
                } else {
                    switch appState.phase {
                    case .loading:
                        Text("Loading...")
                    case .onboarding:
                        OnboardingView()
                            .environment(appState)
                    case .main:
                        MainTabView()
                            .environment(appState)
                    }
                }

                if (TutorialManager.shared.open) {
                    TutorialView()
                        .environment(TutorialManager.shared)
                }

                if let popup = PopupManager.shared.currentPopup {
                    PopupView(popup: popup)
                }
            }
            .environment(\.dependencies, container)
            .foregroundStyle(CloveColors.primaryText)
            .toastable()
        }
    }
    
    init() {
        NotificationManager.shared.clearBadge()

        // Track app launch for review prompts and version updates
        AppReviewManager.shared.trackAppLaunch()

        if !selectedColor.isEmpty, let color = selectedColor.toColor() {
            Theme.shared.accent = color
        }
        _ = AnalyticsRolloutCoordinator.shared.prepareDatabase(container.databaseManager)

        if !onboardingCompleted {
            appState.phase = .onboarding
        } else {
            appState.phase = .main
        }
    }
}

private struct AnalyticsMigrationRecoveryView: View {
    let rollout: AnalyticsRolloutCoordinator
    let databaseManager: DatabaseManaging

    var body: some View {
        ContentUnavailableView {
            Label("Clove Needs to Finish Updating", systemImage: "arrow.triangle.2.circlepath")
        } description: {
            Text("Your health records have not been removed. Retry the local database update to continue.")
        } actions: {
            Button("Retry Update") { rollout.retry(databaseManager) }
                .buttonStyle(.borderedProminent)
                .tint(Theme.shared.accent)
        }
        .padding()
    }
}
