import Foundation

@Observable
class OnboardingViewModel {
   var step: OnboardingStep = .welcome
   var baseSettings: UserSettings = .blank
   
   var trackedSymptoms: [TrackedSymptom] = []
   
   func nextStep() {
      switch step {
      case .welcome:
         step = .moduleSelection
      case .moduleSelection:
         if baseSettings.trackSymptoms {
            step = .symptomSelection
         } else {
            step = .colorScheme
         }
      case .symptomSelection:
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
         let _ = SymptomsRepo.shared.saveTrackedSymptoms(trackedSymptoms)
      }
      let _ = UserSettingsRepo.shared.saveSettings(baseSettings)
      
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
   case colorScheme
   case complete
}
