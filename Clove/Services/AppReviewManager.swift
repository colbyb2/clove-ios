//
//  AppReviewManager.swift
//  Clove
//
//  Created by Claude Code on 1/24/26.
//

import Foundation
import StoreKit
import SwiftUI

// MARK: - Protocol

/// Protocol defining the contract for app review management
protocol AppReviewManaging: AnyObject {
    /// Tracks app launches, version updates, and initial install date
    func trackAppLaunch()

    /// Checks eligibility and prompts for review if all criteria are met
    func promptForReviewIfEligible() async

    /// Marks that the user has rated the app (will never prompt again)
    func recordUserRated()

    /// Resets all review tracking (primarily for testing/debugging)
    func resetReviewState()
}

// MARK: - Implementation

@Observable
class AppReviewManager: AppReviewManaging {
    static let shared = AppReviewManager()

    // MARK: - Configuration Constants

    private let minimumDaysSinceInstall = 7
    private let minimumDaysBetweenPrompts = 120
    private let minimumLogsForPrompt = 5
    private let minimumStreakForPrompt = 3
    private let maxPromptsPerYear = 3
    private let daysToWaitAfterVersionUpdate = 3

    // MARK: - Dependencies

    private let logsRepository: LogsRepositoryProtocol
    private let symptomsRepository: SymptomsRepositoryProtocol
    private let dashboardManager: DashboardManager

    // MARK: - Initialization

    /// Production initializer with singleton dependencies
    private convenience init() {
        self.init(
            logsRepository: LogsRepo.shared,
            symptomsRepository: SymptomsRepo.shared,
            dashboardManager: DashboardManager.shared
        )
    }

    /// Testable initializer with dependency injection
    init(
        logsRepository: LogsRepositoryProtocol,
        symptomsRepository: SymptomsRepositoryProtocol,
        dashboardManager: DashboardManager
    ) {
        self.logsRepository = logsRepository
        self.symptomsRepository = symptomsRepository
        self.dashboardManager = dashboardManager
    }

    // MARK: - Public Methods

    func trackAppLaunch() {
        setupInstallDateIfNeeded()
        trackVersionUpdate()
        resetPromptCountIfNewYear()
    }

    func promptForReviewIfEligible() async {
        // Check if we should prompt
        guard await checkShouldPromptForReview() else {
            return
        }

        // Request review on main actor
        await MainActor.run {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: windowScene)
                recordPromptShown()
            }
        }
    }

    func recordUserRated() {
        UserDefaults.standard.set(true, forKey: Constants.USER_HAS_RATED)
    }

    func resetReviewState() {
        UserDefaults.standard.removeObject(forKey: Constants.APP_INSTALL_DATE)
        UserDefaults.standard.removeObject(forKey: Constants.LAST_RATING_PROMPT_DATE)
        UserDefaults.standard.removeObject(forKey: Constants.RATING_PROMPT_COUNT_THIS_YEAR)
        UserDefaults.standard.removeObject(forKey: Constants.RATING_PROMPT_YEAR)
        UserDefaults.standard.removeObject(forKey: Constants.USER_HAS_RATED)
        UserDefaults.standard.removeObject(forKey: Constants.RATING_PROMPT_DECLINED_VERSION)
        UserDefaults.standard.removeObject(forKey: Constants.VERSION_UPDATE_DATE)
    }

    // MARK: - Private Setup Methods

    private func setupInstallDateIfNeeded() {
        if UserDefaults.standard.object(forKey: Constants.APP_INSTALL_DATE) == nil {
            UserDefaults.standard.set(Date(), forKey: Constants.APP_INSTALL_DATE)
        }
    }

    private func trackVersionUpdate() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let lastVersion = UserDefaults.standard.string(forKey: "lastAppVersion")

        // If version changed, record the update date
        if lastVersion != nil && lastVersion != currentVersion {
            UserDefaults.standard.set(Date(), forKey: Constants.VERSION_UPDATE_DATE)
        }

        // Always update the stored version
        UserDefaults.standard.set(currentVersion, forKey: "lastAppVersion")
    }

    private func resetPromptCountIfNewYear() {
        let currentYear = Calendar.current.component(.year, from: Date())
        let storedYear = UserDefaults.standard.integer(forKey: Constants.RATING_PROMPT_YEAR)

        // Reset count if we're in a new year
        if storedYear != currentYear {
            UserDefaults.standard.set(0, forKey: Constants.RATING_PROMPT_COUNT_THIS_YEAR)
            UserDefaults.standard.set(currentYear, forKey: Constants.RATING_PROMPT_YEAR)
        }
    }

    // MARK: - Eligibility Checks

    private func checkShouldPromptForReview() async -> Bool {
        // Never prompt if user already rated
        if UserDefaults.standard.bool(forKey: Constants.USER_HAS_RATED) {
            return false
        }

        // Check timing requirements
        guard meetsTimingRequirements() else {
            return false
        }

        // Check engagement requirements
        guard await hasMinimumEngagement() else {
            return false
        }

        // Check iOS system limits (max 3 per year)
        guard await meetsPromptLimits() else {
            return false
        }

        // Check if user declined on this major version
        guard !declinedCurrentVersion() else {
            return false
        }

        return true
    }

    private func meetsTimingRequirements() -> Bool {
        let now = Date()

        // Check minimum days since install
        if let installDate = UserDefaults.standard.object(forKey: Constants.APP_INSTALL_DATE) as? Date {
            let daysSinceInstall = Calendar.current.dateComponents([.day], from: installDate, to: now).day ?? 0
            guard daysSinceInstall >= minimumDaysSinceInstall else {
                return false
            }
        } else {
            return false
        }

        // Check cooldown period since last prompt
        if let lastPromptDate = UserDefaults.standard.object(forKey: Constants.LAST_RATING_PROMPT_DATE) as? Date {
            let daysSinceLastPrompt = Calendar.current.dateComponents([.day], from: lastPromptDate, to: now).day ?? 0
            guard daysSinceLastPrompt >= minimumDaysBetweenPrompts else {
                return false
            }
        }

        // Check if recently updated (wait 3 days after version update)
        if let versionUpdateDate = UserDefaults.standard.object(forKey: Constants.VERSION_UPDATE_DATE) as? Date {
            let daysSinceUpdate = Calendar.current.dateComponents([.day], from: versionUpdateDate, to: now).day ?? 0
            guard daysSinceUpdate >= daysToWaitAfterVersionUpdate else {
                return false
            }
        }

        return true
    }

    private func hasMinimumEngagement() async -> Bool {
        // Check minimum logs
        let logsCount = logsRepository.getLogs().count
        guard logsCount >= minimumLogsForPrompt else {
            return false
        }

        // Check that user has configured at least one symptom (completed onboarding meaningfully)
        let trackedSymptoms = symptomsRepository.getTrackedSymptoms()
        guard !trackedSymptoms.isEmpty else {
            return false
        }

        // Check current streak (user must have 3+ day streak)
        // Refresh dashboard data to get latest streaks
        await dashboardManager.refreshDashboard()

        let streaks = dashboardManager.currentStreaks
        let hasGoodStreak = streaks.contains { $0.currentStreak >= minimumStreakForPrompt }

        guard hasGoodStreak else {
            return false
        }

        return true
    }

    private func meetsPromptLimits() async -> Bool {
        let currentYear = Calendar.current.component(.year, from: Date())
        let storedYear = UserDefaults.standard.integer(forKey: Constants.RATING_PROMPT_YEAR)

        // If stored year doesn't match current year, we're good to go
        if storedYear != currentYear {
            return true
        }

        // Check if we've hit the max prompts for this year
        let promptCount = UserDefaults.standard.integer(forKey: Constants.RATING_PROMPT_COUNT_THIS_YEAR)
        return promptCount < maxPromptsPerYear
    }

    private func declinedCurrentVersion() -> Bool {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let majorVersion = currentVersion.split(separator: ".").first.map(String.init) ?? "1"

        if let declinedVersion = UserDefaults.standard.string(forKey: Constants.RATING_PROMPT_DECLINED_VERSION) {
            let declinedMajorVersion = declinedVersion.split(separator: ".").first.map(String.init) ?? "0"
            return majorVersion == declinedMajorVersion
        }

        return false
    }

    // MARK: - Recording Methods

    private func recordPromptShown() {
        let currentDate = Date()
        let currentYear = Calendar.current.component(.year, from: currentDate)
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

        // Update last prompt date
        UserDefaults.standard.set(currentDate, forKey: Constants.LAST_RATING_PROMPT_DATE)

        // Increment prompt count for this year
        let currentCount = UserDefaults.standard.integer(forKey: Constants.RATING_PROMPT_COUNT_THIS_YEAR)
        UserDefaults.standard.set(currentCount + 1, forKey: Constants.RATING_PROMPT_COUNT_THIS_YEAR)
        UserDefaults.standard.set(currentYear, forKey: Constants.RATING_PROMPT_YEAR)

        // Record that we prompted on this version (in case user declines)
        UserDefaults.standard.set(currentVersion, forKey: Constants.RATING_PROMPT_DECLINED_VERSION)
    }
}
