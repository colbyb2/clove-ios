import SwiftUI


@Observable
class TutorialManager {
   static let shared = TutorialManager()
   
   var currentTutorial: Tutorial?
   var open: Bool = false
   var currentStep: Int = 0
   
   private init() {}
   
   func startTutorial(_ tutorial: Tutorial) -> TutorialError? {
      guard !tutorial.shouldDisplay() else { return .Completed }
      guard tutorial.steps.count > 0 else { return .Failure }
      
      self.currentStep = 0
      self.currentTutorial = tutorial
      self.open = true
      
      return nil
   }
   
   func resetTutorial(_ tutorial: Tutorial) -> TutorialError? {
      guard tutorial.steps.count > 0 else { return .Failure }
      
      self.currentStep = 0
      self.currentTutorial = tutorial
      self.open = true
      
      return nil
   }
   
   func nextStep() {
      guard let tutorial = self.currentTutorial else { return }
      let nextStep = currentStep + 1
      guard nextStep < tutorial.steps.count else {
         return self.complete()
      }
      
      currentStep = nextStep
   }
   
   func complete() {
      guard let tutorial = self.currentTutorial else { return }
      tutorial.complete()
      self.open = false
      self.currentTutorial = nil
   }
}

struct TutorialStep: Identifiable {
   let id: Int
   let icon: String
   let title: String
   let description: String
   let subtitle: String?
}

struct Tutorial: Identifiable {
   let id: String
   let steps: [TutorialStep]
   
   func shouldDisplay() -> Bool {
      return UserDefaults.standard.bool(forKey: id)
   }
   
   func complete() {
      UserDefaults.standard.set(true, forKey: id)
   }
}

enum TutorialError {
   case Completed
   case Failure
}
