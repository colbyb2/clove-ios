import SwiftUI


struct TutorialView: View {
   @Environment(TutorialManager.self) var manager
   
   var body: some View {
      ZStack {
         if let step = manager.currentTutorial?.steps[manager.currentStep] {
            TutorialSlide(step: step)
         }
      }
   }
}

struct TutorialSlide: View {
   let step: TutorialStep
   
   @Environment(TutorialManager.self) var manager
   @State private var animateIcon = false
   @State private var animateContent = false
   
   var totalSteps: Int {
      return manager.currentTutorial?.steps.count ?? 0
   }
   
   var stepNum: Int {
      return manager.currentStep + 1
   }
   
   var body: some View {
      ZStack {
         Color.black.opacity(0.4)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.3), value: true)
         
         VStack(spacing: 24) {
            // Dynamic Icon based on card
            customIcon
            
            // Dynamic Title
            Text(step.title)
               .font(.system(size: 28, weight: .bold, design: .rounded))
               .foregroundColor(.primary)
               .multilineTextAlignment(.center)
               .opacity(animateContent ? 1 : 0)
               .offset(y: animateContent ? 0 : 20)
               .animation(.easeOut(duration: 0.6).delay(0.3), value: animateContent)
            
            // Dynamic Description
            customDescription
            
            // Continue/Skip Buttons
            actionButtons
            
            // Dynamic Progress Indicator
            customProgressIndicator
         }
         .padding(32)
         .frame(maxWidth: .infinity)
         .background(tutorialCardBackground)
         .padding(.horizontal, 20)
         .opacity(animateContent ? 1 : 0)
         .scaleEffect(animateContent ? 1 : 0.9)
         .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateContent)
      }
      .onAppear {
         animateIcon = true
         animateContent = true
      }
   }
   
   private var customIcon: some View {
      ZStack {
         Circle()
            .fill(
               RadialGradient(
                  colors: [
                     Theme.shared.accent.opacity(0.2),
                     Theme.shared.accent.opacity(0.1)
                  ],
                  center: .center,
                  startRadius: 10,
                  endRadius: 50
               )
            )
            .frame(width: 100, height: 100)
            .scaleEffect(animateIcon ? 1 : 0.8)
            .opacity(animateIcon ? 1 : 0)
            .animation(.spring(response: 0.8, dampingFraction: 0.6), value: animateIcon)
         
         Image(systemName: step.icon)
            .font(.system(size: 48, weight: .medium))
            .foregroundColor(Theme.shared.accent)
            .scaleEffect(animateIcon ? 1 : 0.5)
            .rotationEffect(.degrees(animateIcon ? 0 : -180))
            .opacity(animateIcon ? 1 : 0)
            .animation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.2), value: animateIcon)
      }
   }
   
   private var customDescription: some View {
      VStack(spacing: 16) {
         Text(step.description)
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(.primary)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
         
         if let subtitle = step.subtitle {
            Text(subtitle)
               .font(.system(size: 16, weight: .regular))
               .foregroundColor(.secondary)
               .multilineTextAlignment(.center)
               .lineSpacing(2)
         }
      }
      .opacity(animateContent ? 1 : 0)
      .offset(y: animateContent ? 0 : 30)
      .animation(.easeOut(duration: 0.6).delay(0.5), value: animateContent)
   }
   
   private var actionButtons: some View {
      HStack(spacing: 16) {
         // Skip button (except for last step)
         if stepNum < totalSteps {
            Button(action: {
               let impactFeedback = UIImpactFeedbackGenerator(style: .light)
               impactFeedback.impactOccurred()
               manager.complete()
            }) {
               Text("Skip")
                  .font(.system(size: 16, weight: .semibold))
                  .foregroundColor(.secondary)
                  .frame(height: 48)
                  .frame(maxWidth: .infinity)
                  .background(
                     RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                  )
            }
         }
         
         // Continue/Finish button
         Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            manager.nextStep()
         }) {
            HStack(spacing: 8) {
               Text(stepNum == totalSteps ? "Finish" : "Continue")
                  .font(.system(size: 16, weight: .semibold))
                  .foregroundColor(.white)
               
               if stepNum < totalSteps {
                  Image(systemName: "arrow.right")
                     .font(.system(size: 14, weight: .semibold))
                     .foregroundColor(.white)
               }
            }
            .frame(height: 48)
            .frame(maxWidth: .infinity)
            .background(
               RoundedRectangle(cornerRadius: 12)
                  .fill(Theme.shared.accent)
                  .shadow(
                     color: Theme.shared.accent.opacity(0.3),
                     radius: 6,
                     x: 0,
                     y: 3
                  )
            )
         }
      }
      .opacity(animateContent ? 1 : 0)
      .offset(y: animateContent ? 0 : 40)
      .animation(.easeOut(duration: 0.6).delay(0.7), value: animateContent)
   }
   
   private var customProgressIndicator: some View {
      VStack(spacing: 12) {
         HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
               Circle()
                  .fill(index < stepNum ? Theme.shared.accent : Color(.systemGray4))
                  .frame(width: 8, height: 8)
                  .scaleEffect(index == stepNum - 1 ? 1.2 : 1.0)
                  .animation(.easeInOut(duration: 0.3), value: manager.currentStep)
            }
         }
         
         HStack(spacing: 4) {
            Text("Step")
               .font(.system(size: 14, weight: .medium))
               .foregroundColor(.secondary)
            
            Text("\(stepNum)")
               .font(.system(size: 14, weight: .bold))
               .foregroundColor(Theme.shared.accent)
            
            Text("of")
               .font(.system(size: 14, weight: .medium))
               .foregroundColor(.secondary)
            
            Text("\(totalSteps)")
               .font(.system(size: 14, weight: .medium))
               .foregroundColor(.secondary)
         }
      }
      .opacity(animateContent ? 1 : 0)
      .offset(y: animateContent ? 0 : 20)
      .animation(.easeOut(duration: 0.6).delay(0.9), value: animateContent)
      .accessibilityLabel("Tutorial progress: step \(stepNum) of \(totalSteps)")
   }
   
   private var tutorialCardBackground: some View {
      RoundedRectangle(cornerRadius: 24)
         .fill(Color(.systemBackground))
         .overlay(
            RoundedRectangle(cornerRadius: 24)
               .stroke(
                  LinearGradient(
                     colors: [
                        Theme.shared.accent.opacity(0.2),
                        Theme.shared.accent.opacity(0.05)
                     ],
                     startPoint: .topLeading,
                     endPoint: .bottomTrailing
                  ),
                  lineWidth: 1
               )
         )
         .shadow(
            color: .black.opacity(0.1),
            radius: 20,
            x: 0,
            y: 10
         )
   }
}

#Preview {
   ZStack {
      // Simulated background content
      VStack(spacing: 20) {
         Rectangle()
            .fill(Color(.systemGray5))
            .frame(height: 100)
            .cornerRadius(12)
         
         Rectangle()
            .fill(Color(.systemGray5))
            .frame(height: 150)
            .cornerRadius(12)
         
         Rectangle()
            .fill(Color(.systemGray5))
            .frame(height: 120)
            .cornerRadius(12)
      }
      .padding()
      
      // Tutorial overlay
      TutorialSlide(step: TutorialStep(id: 1, icon: "tray.2", title: "Test Tutorial", description: "This is a mocked tutorial slide", subtitle: nil))
         .environment(TutorialManager.shared)
   }
}
