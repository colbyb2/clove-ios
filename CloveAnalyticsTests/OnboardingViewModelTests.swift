import Foundation
import XCTest
@testable import Clove

final class OnboardingViewModelTests: XCTestCase {
    private let draftKey = "cloveOnboardingDraftV2"
    private lazy var touchedKeys = [
        draftKey,
        Constants.ONBOARDING_FLAG,
        Constants.PACING_PLANS_ENABLED,
        Constants.SELECTED_COLOR,
        Tutorials.TodayView.id
    ]
    private var savedDefaults: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        // The view model writes to UserDefaults.standard; isolate each test
        // and restore the host app's values afterwards.
        for key in touchedKeys {
            savedDefaults[key] = UserDefaults.standard.object(forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for key in touchedKeys {
            if let value = savedDefaults[key] {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        super.tearDown()
    }

    func testStepsSkipSymptomSelectionWhenSymptomsAreOff() {
        let viewModel = makeViewModel()
        viewModel.baseSettings.trackSymptoms = false
        viewModel.step = .moduleSelection

        viewModel.nextStep()
        XCTAssertEqual(viewModel.step, .notifications)
        XCTAssertEqual(viewModel.setupSteps, [.moduleSelection, .notifications, .colorScheme, .terms])

        viewModel.previousStep()
        XCTAssertEqual(viewModel.step, .moduleSelection)
    }

    func testForwardThenBackwardWalksTheSameStepsWhenSymptomsAreOn() {
        let viewModel = makeViewModel()
        viewModel.baseSettings.trackSymptoms = true
        var forward: [OnboardingStep] = [viewModel.step]
        while viewModel.step != .complete {
            viewModel.nextStep()
            forward.append(viewModel.step)
        }
        var backward: [OnboardingStep] = [viewModel.step]
        while viewModel.step != .welcome {
            viewModel.previousStep()
            backward.append(viewModel.step)
        }

        XCTAssertEqual(forward, backward.reversed())
        XCTAssertTrue(forward.contains(.symptomSelection))
    }

    func testProgressCountsOnlySetupSteps() {
        let viewModel = makeViewModel()
        viewModel.step = .welcome
        XCTAssertNil(viewModel.progressText)
        XCTAssertEqual(viewModel.progress, 0)

        viewModel.step = .terms
        XCTAssertEqual(viewModel.progress, 1, accuracy: 1e-9)
        XCTAssertEqual(viewModel.progressText, "Step \(viewModel.setupSteps.count) of \(viewModel.setupSteps.count)")
    }

    func testAddingSymptomsTrimsRejectsDuplicatesAndKeepsOrderContiguous() {
        let viewModel = makeViewModel()

        XCTAssertTrue(viewModel.addSymptom(name: "  Fatigue "))
        XCTAssertFalse(viewModel.addSymptom(name: "fatigue"), "Case-insensitive duplicate")
        XCTAssertFalse(viewModel.addSymptom(name: "   "))
        XCTAssertTrue(viewModel.addSymptom(name: "Nausea", isBinary: true))
        XCTAssertTrue(viewModel.addSymptom(name: "Brain fog"))

        viewModel.removeSymptom(at: 0)
        viewModel.toggleSuggestedSymptom("NAUSEA")

        XCTAssertEqual(viewModel.trackedSymptoms.map(\.name), ["Brain fog"])
        XCTAssertEqual(viewModel.trackedSymptoms.map(\.displayOrder), [0])
    }

    func testDraftSurvivesRelaunch() {
        let first = makeViewModel()
        first.baseSettings.trackPain = true
        first.addSymptom(name: "Migraine", isBinary: true)
        first.step = .moduleSelection
        first.nextStep()

        let relaunched = makeViewModel()

        XCTAssertEqual(relaunched.step, .symptomSelection)
        XCTAssertTrue(relaunched.baseSettings.trackPain)
        XCTAssertEqual(relaunched.trackedSymptoms.map(\.name), ["Migraine"])
        XCTAssertEqual(relaunched.trackedSymptoms.first?.isBinary, true)
    }

    func testCompletingPersistsChoicesAndClearsDraft() {
        let settings = MockUserSettingsRepository()
        let symptoms = MockSymptomsRepository()
        let viewModel = makeViewModel(settings: settings, symptoms: symptoms)
        viewModel.baseSettings.trackSymptoms = true
        viewModel.addSymptom(name: "Joint pain")
        viewModel.pacingPlansEnabled = true
        let appState = AppState()

        XCTAssertTrue(viewModel.completeOnboarding(appState: appState, showTutorial: false))

        XCTAssertEqual(appState.phase, .main)
        XCTAssertEqual(settings.settings?.trackSymptoms, true)
        XCTAssertEqual(symptoms.symptoms.map(\.name), ["Joint pain"])
        XCTAssertTrue(UserDefaults.standard.bool(forKey: Constants.ONBOARDING_FLAG))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: Constants.PACING_PLANS_ENABLED))
        XCTAssertNil(UserDefaults.standard.data(forKey: draftKey))
    }

    func testFailedCompletionKeepsChoicesAndDoesNotEnterApp() {
        let settings = MockUserSettingsRepository()
        settings.shouldSucceed = false
        let viewModel = makeViewModel(settings: settings)
        viewModel.addSymptom(name: "Dizziness")
        let appState = AppState()

        XCTAssertFalse(viewModel.completeOnboarding(appState: appState, showTutorial: true))

        XCTAssertEqual(appState.phase, .loading)
        XCTAssertNotNil(viewModel.completionError)
        XCTAssertFalse(viewModel.isCompleting, "User can retry")
        XCTAssertEqual(viewModel.trackedSymptoms.map(\.name), ["Dizziness"])
        XCTAssertFalse(UserDefaults.standard.bool(forKey: Constants.ONBOARDING_FLAG))
    }

    private func makeViewModel(
        settings: MockUserSettingsRepository = MockUserSettingsRepository(),
        symptoms: MockSymptomsRepository = MockSymptomsRepository()
    ) -> OnboardingViewModel {
        OnboardingViewModel(symptomsRepository: symptoms, settingsRepository: settings)
    }
}
