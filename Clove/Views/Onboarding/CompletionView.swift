import SwiftUI

struct CompleteView: View {
   @Environment(AppState.self) var appState
   @Environment(OnboardingViewModel.self) var viewModel
   
   @State var animateDone: Bool = false
   
   var body: some View {
      ZStack {
         VStack(spacing: 30) {
            Spacer()
            
            Text("You are ready to go!")
               .font(.system(.title, design: .rounded).weight(.semibold))
               .foregroundStyle(CloveColors.primary)
               .multilineTextAlignment(.center)
               .offset(x: animateDone ? 400 : 0)
            
            Text("It is important to us that Clove remains free and private. Your data is safe and secure on your own device.")
               .font(.system(.headline, design: .rounded).weight(.semibold))
               .foregroundStyle(CloveColors.secondaryText)
               .multilineTextAlignment(.center)
               .offset(x: animateDone ? -400 : 0)
            
            Spacer()
            
            CloveButton(text: "Done", fontColor: .white) {
               Task {
                  self.animateDone = true
                  try? await Task.sleep(for: .seconds(3))
                  viewModel.completeOnboarding(appState: appState)
               }
            }
            .opacity(animateDone ? 0 : 1)
         }
         .padding()
         
         Image(systemName: "leaf.circle.fill") // Placeholder for custom branding
            .resizable()
            .scaledToFit()
            .frame(width: 100, height: 100)
            .foregroundStyle(CloveColors.primary.opacity(!animateDone ? 0.0 : 0.9))
      }
      .animation(.easeInOut(duration: 1.8), value: animateDone)
    }
}

#Preview {
    CompleteView()
      .environment(OnboardingViewModel())
      .environment(AppState())
}
