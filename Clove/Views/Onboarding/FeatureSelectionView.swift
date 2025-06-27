import SwiftUI

struct FeatureSelectionView: View {
   @Environment(OnboardingViewModel.self) var viewModel
   
   var body: some View {
      VStack {
         VStack(spacing: 20) {
            Text("What do you want to keep track of?")
               .font(.system(.title, design: .rounded).weight(.semibold))
               .foregroundStyle(CloveColors.primary)
            Text("Our health can be exhausting, don't overwhelm yourself.")
               .foregroundStyle(CloveColors.secondaryText)
         }
         .multilineTextAlignment(.center)
         
         ScrollView {
            @Bindable var vm = viewModel
            
            VStack(spacing: 15) {
               featureButton(name: "Symptoms", icon: "list.bullet.clipboard.fill", color: Color(hex: "b17ad6"), selected: $vm.baseSettings.trackSymptoms)
               featureButton(name: "Mood", icon: "figure.mind.and.body", color: Color(hex: "fc88fa"), selected: $vm.baseSettings.trackMood)
               featureButton(name: "Pain", icon: "stethoscope", color: Color(hex: "6080af"), selected: $vm.baseSettings.trackPain)
               featureButton(name: "Energy", icon: "bolt.fill", color: Color(hex: "60af62"), selected: $vm.baseSettings.trackEnergy)
               featureButton(name: "Meals", icon: "fork.knife", color: Color(hex: "72aae5"), selected: $vm.baseSettings.trackMeals)
               featureButton(name: "Activities", icon: "figure.run", color: Color(hex: "e5b772"), selected: $vm.baseSettings.trackActivities)
               featureButton(name: "Medications", icon: "pills.fill", color: Color(hex: "6eb59e"), selected: $vm.baseSettings.trackMeds)
               featureButton(name: "Flare Ups", icon: "flame.fill", color: Color(hex: "ed5c40"), selected: $vm.baseSettings.showFlareToggle)
            }
            .padding(.vertical)
         }
         .scrollIndicators(.hidden)
         .padding()
         .padding(.horizontal)
         
         CloveButton(text: !viewModel.baseSettings.isSomeEnabled() ? "Select at least one..." : "Continue", fontColor: .white) {
            viewModel.nextStep()
         }
         .padding()
         .disabled(!viewModel.baseSettings.isSomeEnabled())
         .animation(.easeInOut, value: viewModel.baseSettings.isSomeEnabled())
      }
      .padding(.top, 50)
   }
   
   func featureButton(name: String, icon: String, color: Color, selected: Binding<Bool>) -> some View {
      HStack {
         HStack {
            Image(systemName: icon)
               .resizable()
               .scaledToFit()
               .frame(width: 30, height: 30)
            Text(name)
               .font(.system(size: 20, weight: .semibold))
         }
         .foregroundStyle(color)
         
         Spacer()
         
         Image(systemName: selected.wrappedValue ? "checkmark.circle.fill" : "circle")
            .resizable()
            .scaledToFit()
            .frame(width: selected.wrappedValue ? 25 : 20)
            .foregroundStyle(selected.wrappedValue ? CloveColors.success : .secondaryText)
      }
      .padding()
      .background(CloveColors.card)
      .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
      .shadow(color: .gray.opacity(0.3), radius: 2)
      .onTapGesture {
         selected.wrappedValue.toggle()
      }
      .animation(.bouncy, value: selected.wrappedValue)
   }
}

#Preview {
   FeatureSelectionView()
      .environment(OnboardingViewModel())
}
