import SwiftUI

struct WelcomeView: View {
    @Environment(OnboardingViewModel.self) var viewModel
    @State private var iconScale: CGFloat = 0.8
    @State private var contentOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 50
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Theme.shared.accent.opacity(0.05),
                        Theme.shared.accent.opacity(0.1),
                        Color.clear
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Hero content
                    VStack(spacing: 24) {
                        // Icon with enhanced styling
                        ZStack {
                            // Soft shadow circle
                            Circle()
                                .fill(Theme.shared.accent.opacity(0.1))
                                .frame(width: 140, height: 140)
                                .blur(radius: 20)
                                .offset(y: 10)
                            
                            // Icon background
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Theme.shared.accent.opacity(0.8),
                                            Theme.shared.accent.opacity(0.6)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                            
                            // Main icon
                            Image(systemName: "leaf.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .foregroundStyle(.white)
                        }
                        .scaleEffect(iconScale)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6), value: iconScale)
                        
                        // Text content
                        VStack(spacing: 16) {
                            Text("Welcome to Clove")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Theme.shared.accent,
                                            Theme.shared.accent.opacity(0.8)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Text("A gentle way to track what matters most for your health.")
                                .font(.system(.title3, design: .rounded))
                                .foregroundStyle(CloveColors.secondaryText)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal, 32)
                        }
                        .opacity(contentOpacity)
                        .animation(.easeInOut(duration: 0.8).delay(0.3), value: contentOpacity)
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    // Enhanced button area
                    VStack(spacing: 16) {
                        CloveButton(text: "Get Started", fontColor: .white) {
                            viewModel.nextStep()
                        }
                        .shadow(color: Theme.shared.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                        .scaleEffect(0.98)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: buttonOffset)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 24))
                    .offset(y: buttonOffset)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6), value: buttonOffset)
                }
            }
        }
        .onAppear {
            // Trigger animations
            withAnimation {
                iconScale = 1.0
                contentOpacity = 1.0
                buttonOffset = 0
            }
        }
    }
}

#Preview {
    WelcomeView()
        .environment(OnboardingViewModel())
}
