import SwiftUI

struct FeatureSelectionView: View {
    @Environment(OnboardingViewModel.self) var viewModel
    @State private var headerOpacity: Double = 0
    @State private var buttonAnimationTrigger: Bool = false
    @State private var buttonOffset: CGFloat = 30
    
    var body: some View {
        VStack {
            VStack(spacing: 20) {
                Text("What do you want to keep track of?")
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.shared.accent)
                Text("Our health can be exhausting, don't overwhelm yourself.")
                    .foregroundStyle(CloveColors.secondaryText)
            }
            .multilineTextAlignment(.center)
            .opacity(headerOpacity)
            .animation(.easeInOut(duration: 0.8), value: headerOpacity)
            
            ScrollView {
                @Bindable var vm = viewModel
                
                VStack(spacing: 15) {
                    featureButton(name: "Symptoms", icon: "list.bullet.clipboard.fill", color: Color(hex: "b17ad6"), selected: $vm.baseSettings.trackSymptoms, animationDelay: 0.1)
                    featureButton(name: "Mood", icon: "figure.mind.and.body", color: Color(hex: "fc88fa"), selected: $vm.baseSettings.trackMood, animationDelay: 0.2)
                    featureButton(name: "Pain", icon: "stethoscope", color: Color(hex: "6080af"), selected: $vm.baseSettings.trackPain, animationDelay: 0.3)
                    featureButton(name: "Energy", icon: "bolt.fill", color: Color(hex: "60af62"), selected: $vm.baseSettings.trackEnergy, animationDelay: 0.4)
                    featureButton(name: "Meals", icon: "fork.knife", color: Color(hex: "72aae5"), selected: $vm.baseSettings.trackMeals, animationDelay: 0.5)
                    featureButton(name: "Activities", icon: "figure.run", color: Color(hex: "e5b772"), selected: $vm.baseSettings.trackActivities, animationDelay: 0.6)
                    featureButton(name: "Medications", icon: "pills.fill", color: Color(hex: "6eb59e"), selected: $vm.baseSettings.trackMeds, animationDelay: 0.7)
                    featureButton(name: "Weather", icon: "cloud.sun.fill", color: Color(hex: "8ec5ff"), selected: $vm.baseSettings.trackWeather, animationDelay: 0.8)
                    featureButton(name: "Flare Ups", icon: "flame.fill", color: Color(hex: "ed5c40"), selected: $vm.baseSettings.showFlareToggle, animationDelay: 0.9)
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
            .opacity(headerOpacity)
            .offset(y: buttonOffset)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.0), value: buttonOffset)
        }
        .padding(.top, 50)
        .onAppear {
            // Trigger entrance animations
            withAnimation {
                headerOpacity = 1.0
                buttonAnimationTrigger = true
                buttonOffset = 0
            }
        }
    }
    
    func featureButton(name: String, icon: String, color: Color, selected: Binding<Bool>, animationDelay: Double) -> some View {
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
                .frame(width: 20)
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
        .opacity(buttonAnimationTrigger ? 1.0 : 0)
        .offset(x: buttonAnimationTrigger ? 0 : -50)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(animationDelay), value: buttonAnimationTrigger)
    }
}

#Preview {
    FeatureSelectionView()
        .environment(OnboardingViewModel())
}
