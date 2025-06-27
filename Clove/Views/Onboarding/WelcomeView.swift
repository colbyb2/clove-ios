import SwiftUI

struct WelcomeView: View {
   @Environment(OnboardingViewModel.self) var viewModel
   
   var body: some View {
      VStack(spacing: 32) {
         
         Spacer()
         
         VStack(spacing: 16) {
            Image(systemName: "leaf.circle.fill") // Placeholder for custom branding
               .resizable()
               .scaledToFit()
               .frame(width: 100, height: 100)
               .foregroundStyle(CloveColors.primary.opacity(0.7)) // Customize to your brand palette
            
            Text("Welcome to Clove")
               .font(.system(.largeTitle, design: .rounded).weight(.semibold))
               .multilineTextAlignment(.center)
               .padding(.horizontal)
            
            Text("A gentle way to track what matters most for your health.")
               .font(.system(.body, design: .rounded))
               .foregroundStyle(CloveColors.secondaryText)
               .multilineTextAlignment(.center)
               .padding(.horizontal, 32)
         }
         
         Spacer()
         
         CloveButton(text: "Get Started", fontColor: .white){
            viewModel.nextStep()
         }
         .padding(.horizontal)
         .padding(.bottom, 24)
      }
      .padding()
      .ignoresSafeArea(edges: .bottom)
   }
}


#Preview {
   WelcomeView()
      .environment(OnboardingViewModel())
}
