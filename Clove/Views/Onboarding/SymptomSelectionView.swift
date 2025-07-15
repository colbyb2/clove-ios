import SwiftUI

struct SymptomSelectionView: View {
   @Environment(OnboardingViewModel.self) var viewModel
   
   var body: some View {
      EditSymptomsSheet(trackedSymptoms: [], hideCancel: true, onDone: {
         viewModel.nextStep()
      })
   }
}

#Preview {
   SymptomSelectionView()
      .environment(OnboardingViewModel())
}
