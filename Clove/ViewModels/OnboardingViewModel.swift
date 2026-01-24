import Foundation

@Observable
class OnboardingViewModel {
   // MARK: - Dependencies
   private let symptomsRepository: SymptomsRepositoryProtocol
   private let settingsRepository: UserSettingsRepositoryProtocol

   // MARK: - State
   var step: OnboardingStep = .welcome
   var baseSettings: UserSettings = .blank
   var trackedSymptoms: [TrackedSymptom] = []

   // MARK: - Initialization

   /// Convenience initializer using production singletons
   convenience init() {
      self.init(
         symptomsRepository: SymptomsRepo.shared,
         settingsRepository: UserSettingsRepo.shared
      )
   }

   /// Designated initializer with full dependency injection
   init(
      symptomsRepository: SymptomsRepositoryProtocol,
      settingsRepository: UserSettingsRepositoryProtocol
   ) {
      self.symptomsRepository = symptomsRepository
      self.settingsRepository = settingsRepository
   }

   /// Preview factory with mock dependencies
   static func preview(step: OnboardingStep = .welcome) -> OnboardingViewModel {
      let container = MockDependencyContainer()
      let vm = OnboardingViewModel(
         symptomsRepository: container.symptomsRepository,
         settingsRepository: container.settingsRepository
      )
      vm.step = step
      return vm
   }

   func nextStep() {
      switch step {
      case .welcome:
         step = .moduleSelection
      case .moduleSelection:
         if baseSettings.trackSymptoms {
            step = .symptomSelection
         } else {
            step = .insightsComplexity
         }
      case .symptomSelection:
         step = .insightsComplexity
      case .insightsComplexity:
         step = .notifications
      case .notifications:
         step = .colorScheme
      case .colorScheme:
         step = .complete
      case .complete:
         return
      }
   }
   
   func addSymptom(name: String) {
      guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
      
      let newSymptom = TrackedSymptom(
         name: name.trimmingCharacters(in: .whitespacesAndNewlines)
      )
      
      trackedSymptoms.append(newSymptom)
   }
   
   func removeSymptom(at indexSet: IndexSet) {
      trackedSymptoms.remove(atOffsets: indexSet)
   }
   
   func completeOnboarding(appState: AppState) {
      if !trackedSymptoms.isEmpty {
         let _ = symptomsRepository.saveTrackedSymptoms(trackedSymptoms)
      }
      let _ = settingsRepository.saveSettings(baseSettings)

      UserDefaults.standard.set(true, forKey: Constants.ONBOARDING_FLAG)
      // Mark that we've shown location permission during onboarding
      UserDefaults.standard.set(true, forKey: "locationPermissionRequested")

      appState.phase = .main
   }
}

enum OnboardingStep {
   case welcome
   case moduleSelection
   case symptomSelection
   case insightsComplexity
   case notifications
   case colorScheme
   case complete
}
