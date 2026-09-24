import Foundation

@Observable
final class OnboardingViewModel {
    private static let draftKey = "cloveOnboardingDraftV2"
    private let symptomsRepository: SymptomsRepositoryProtocol
    private let settingsRepository: UserSettingsRepositoryProtocol

    var step: OnboardingStep = .welcome
    var baseSettings: UserSettings
    var trackedSymptoms: [TrackedSymptom] = []
    var pacingPlansEnabled = false
    var selectedColorString = ""
    var completionError: String?
    var isCompleting = false

    convenience init() {
        self.init(
            symptomsRepository: SymptomsRepo.shared,
            settingsRepository: UserSettingsRepo.shared
        )
    }

    init(
        symptomsRepository: SymptomsRepositoryProtocol,
        settingsRepository: UserSettingsRepositoryProtocol
    ) {
        self.symptomsRepository = symptomsRepository
        self.settingsRepository = settingsRepository

        if let data = UserDefaults.standard.data(forKey: Self.draftKey),
           let draft = try? JSONDecoder().decode(OnboardingDraft.self, from: data) {
            step = draft.step
            baseSettings = draft.settings
            trackedSymptoms = draft.symptoms
            pacingPlansEnabled = draft.pacingPlansEnabled
            selectedColorString = draft.selectedColorString
        } else {
            var recommended = UserSettings.default
            recommended.trackWeather = false
            recommended.showFlareToggle = false
            baseSettings = recommended
        }
    }

    static func preview(step: OnboardingStep = .welcome) -> OnboardingViewModel {
        let container = MockDependencyContainer()
        let vm = OnboardingViewModel(
            symptomsRepository: container.symptomsRepository,
            settingsRepository: container.settingsRepository
        )
        vm.step = step
        return vm
    }

    var setupSteps: [OnboardingStep] {
        var steps: [OnboardingStep] = [.moduleSelection]
        if baseSettings.trackSymptoms {
            steps.append(.symptomSelection)
        }
        steps.append(contentsOf: [.notifications, .colorScheme, .terms])
        return steps
    }

    var progressText: String? {
        guard let index = setupSteps.firstIndex(of: step) else { return nil }
        return "Step \(index + 1) of \(setupSteps.count)"
    }

    var progress: Double {
        guard let index = setupSteps.firstIndex(of: step) else { return 0 }
        return Double(index + 1) / Double(setupSteps.count)
    }

    func nextStep() {
        switch step {
        case .welcome:
            step = .valueOverview
        case .valueOverview:
            step = .moduleSelection
        case .moduleSelection:
            step = baseSettings.trackSymptoms ? .symptomSelection : .notifications
        case .symptomSelection:
            step = .notifications
        case .notifications:
            step = .colorScheme
        case .colorScheme:
            step = .terms
        case .terms:
            step = .complete
        case .complete:
            break
        }
        persistDraft()
    }

    func previousStep() {
        switch step {
        case .welcome:
            break
        case .valueOverview:
            step = .welcome
        case .moduleSelection:
            step = .valueOverview
        case .symptomSelection:
            step = .moduleSelection
        case .notifications:
            step = baseSettings.trackSymptoms ? .symptomSelection : .moduleSelection
        case .colorScheme:
            step = .notifications
        case .complete:
            step = .terms
        case .terms:
            step = .colorScheme
        }
        persistDraft()
    }

    func useRecommendedTracker() {
        var recommended = UserSettings.default
        recommended.trackWeather = false
        recommended.showFlareToggle = false
        baseSettings = recommended
        pacingPlansEnabled = false
        persistDraft()
    }

    @discardableResult
    func addSymptom(name: String, isBinary: Bool = false) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard !trackedSymptoms.contains(where: {
            $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }) else { return false }

        trackedSymptoms.append(
            TrackedSymptom(
                name: trimmed,
                isBinary: isBinary,
                displayOrder: trackedSymptoms.count
            )
        )
        persistDraft()
        return true
    }

    func toggleSuggestedSymptom(_ name: String) {
        if let index = trackedSymptoms.firstIndex(where: {
            $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }) {
            trackedSymptoms.remove(at: index)
            normalizeSymptomOrder()
            persistDraft()
        } else {
            addSymptom(name: name)
        }
    }

    func setSymptomScale(at index: Int, isBinary: Bool) {
        guard trackedSymptoms.indices.contains(index) else { return }
        trackedSymptoms[index].isBinary = isBinary
        persistDraft()
    }

    func removeSymptom(at index: Int) {
        guard trackedSymptoms.indices.contains(index) else { return }
        trackedSymptoms.remove(at: index)
        normalizeSymptomOrder()
        persistDraft()
    }

    func persistDraft() {
        let draft = OnboardingDraft(
            step: step,
            settings: baseSettings,
            symptoms: trackedSymptoms,
            pacingPlansEnabled: pacingPlansEnabled,
            selectedColorString: selectedColorString
        )
        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: Self.draftKey)
    }

    @discardableResult
    func completeOnboarding(appState: AppState, showTutorial: Bool) -> Bool {
        guard !isCompleting else { return false }
        isCompleting = true
        completionError = nil

        let settingsSaved = settingsRepository.saveSettings(baseSettings)
        let symptomsSaved = !baseSettings.trackSymptoms || symptomsRepository.saveTrackedSymptoms(trackedSymptoms)

        guard settingsSaved, symptomsSaved else {
            completionError = "Clove couldn't finish saving your setup. Your choices are still here—please try again."
            isCompleting = false
            return false
        }

        UserDefaults.standard.set(pacingPlansEnabled, forKey: Constants.PACING_PLANS_ENABLED)
        if !selectedColorString.isEmpty {
            UserDefaults.standard.set(selectedColorString, forKey: Constants.SELECTED_COLOR)
        }

        if showTutorial {
            UserDefaults.standard.removeObject(forKey: Tutorials.TodayView.id)
        } else {
            Tutorials.TodayView.complete()
        }

        UserDefaults.standard.set(true, forKey: Constants.ONBOARDING_FLAG)
        UserDefaults.standard.removeObject(forKey: Self.draftKey)
        appState.completeOnboarding()
        isCompleting = false
        return true
    }

    private func normalizeSymptomOrder() {
        for index in trackedSymptoms.indices {
            trackedSymptoms[index].displayOrder = index
        }
    }
}

private struct OnboardingDraft: Codable {
    let step: OnboardingStep
    let settings: UserSettings
    let symptoms: [TrackedSymptom]
    let pacingPlansEnabled: Bool
    let selectedColorString: String
}

enum OnboardingStep: String, Codable, Hashable {
    case welcome
    case valueOverview
    case moduleSelection
    case symptomSelection
    case notifications
    case colorScheme
    case terms
    case complete
}
