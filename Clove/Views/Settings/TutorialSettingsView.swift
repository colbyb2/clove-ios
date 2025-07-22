import SwiftUI

struct TutorialSettingsView: View {
   @Environment(TutorialManager.self) private var tutorialManager
   @State private var showingError = false
   @State private var errorMessage = ""
   
   var body: some View {
      NavigationView {
         ScrollView {
            VStack(spacing: CloveSpacing.large) {
               // Header Section
               headerSection
               
               // Tutorial Buttons Section
               tutorialsSection
               
               // Help Section
               helpSection
            }
            .padding(.horizontal, CloveSpacing.large)
            .padding(.bottom, CloveSpacing.xlarge)
         }
         .background(CloveColors.background.ignoresSafeArea())
         .navigationTitle("Tutorials")
         .navigationBarTitleDisplayMode(.large)
      }
      .alert("Tutorial Status", isPresented: $showingError) {
         Button("OK", role: .cancel) { }
      } message: {
         Text(errorMessage)
      }
   }
   
   // MARK: - Header Section
   
   private var headerSection: some View {
      VStack(spacing: CloveSpacing.medium) {
         // Icon
         ZStack {
            Circle()
               .fill(Theme.shared.accent.opacity(0.1))
               .frame(width: 80, height: 80)
            
            Image(systemName: "lightbulb.fill")
               .font(.system(size: 32, weight: .medium))
               .foregroundStyle(Theme.shared.accent)
         }
         
         // Title and description
         VStack(spacing: CloveSpacing.small) {
            Text("App Tutorials")
               .font(.system(.title2, design: .rounded, weight: .bold))
               .foregroundStyle(CloveColors.primaryText)
               .multilineTextAlignment(.center)
            
            Text("Learn how to use each feature of Clove with interactive tutorials. Perfect for getting started or refreshing your memory.")
               .font(.system(.body, design: .rounded))
               .foregroundStyle(CloveColors.secondaryText)
               .multilineTextAlignment(.center)
               .lineSpacing(2)
         }
      }
      .padding(CloveSpacing.large)
      .background(
         RoundedRectangle(cornerRadius: CloveCorners.large)
            .fill(CloveColors.card)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
      )
   }
   
   // MARK: - Tutorials Section
   
   private var tutorialsSection: some View {
      VStack(spacing: CloveSpacing.medium) {
         // Section header
         HStack {
            Text("Available Tutorials")
               .font(.system(.title3, design: .rounded, weight: .semibold))
               .foregroundStyle(CloveColors.primaryText)
            
            Spacer()
         }
         .padding(.horizontal, CloveSpacing.small)
         
         // Tutorial buttons
         VStack(spacing: CloveSpacing.small) {
            TutorialButton(
               title: "Today View",
               description: "Learn to log your daily health metrics",
               icon: "sun.max.fill",
               color: .orange,
               tutorial: Tutorials.TodayView
            )
            
            TutorialButton(
               title: "Insights",
               description: "Discover patterns in your health data",
               icon: "chart.bar.fill",
               color: .blue,
               tutorial: Tutorials.InsightsView
            )
            
            TutorialButton(
               title: "Calendar History",
               description: "Explore your past health logs",
               icon: "calendar",
               color: .green,
               tutorial: Tutorials.CalendarView
            )
         }
      }
      .padding(CloveSpacing.large)
      .background(
         RoundedRectangle(cornerRadius: CloveCorners.large)
            .fill(CloveColors.card)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
      )
   }
   
   // MARK: - Help Section
   
   private var helpSection: some View {
      VStack(alignment: .leading, spacing: CloveSpacing.medium) {
         HStack {
            Image(systemName: "info.circle.fill")
               .font(.system(size: 20))
               .foregroundStyle(Theme.shared.accent)
            
            Text("About Tutorials")
               .font(.system(.title3, design: .rounded, weight: .semibold))
               .foregroundStyle(CloveColors.primaryText)
            
            Spacer()
         }
         
         VStack(alignment: .leading, spacing: CloveSpacing.small) {
            HelpRow(
               icon: "play.fill",
               text: "Tutorials guide you through each feature step-by-step"
            )
            
            HelpRow(
               icon: "arrow.right.circle",
               text: "Tap 'Continue' to move between steps"
            )
            
            HelpRow(
               icon: "xmark.circle",
               text: "You can skip or exit tutorials at any time"
            )
            
            HelpRow(
               icon: "checkmark.circle",
               text: "Completed tutorials won't show again automatically"
            )
         }
      }
      .padding(CloveSpacing.large)
      .background(
         RoundedRectangle(cornerRadius: CloveCorners.large)
            .fill(CloveColors.card)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
      )
   }
   
   // MARK: - Helper Methods
   
   private func startTutorial(_ tutorial: Tutorial) {
      let error = tutorialManager.startTutorial(tutorial)
      
      switch error {
      case .Completed:
         errorMessage = "This tutorial has already been completed. Starting it again..."
         showingError = true
         // Start anyway for replay functionality
         tutorialManager.currentStep = 0
         tutorialManager.currentTutorial = tutorial
         tutorialManager.open = true
         
      case .Failure:
         errorMessage = "Unable to start tutorial. Please try again."
         showingError = true
         
      case .none:
         // Tutorial started successfully, no action needed
         break
      }
   }
}

// MARK: - Supporting Views

struct TutorialButton: View {
   let title: String
   let description: String
   let icon: String
   let color: Color
   let tutorial: Tutorial
   @Environment(TutorialManager.self) private var tutorialManager
   @State private var isPressed = false
   
   var body: some View {
      Button(action: {
         startTutorial()
      }) {
         HStack(spacing: CloveSpacing.medium) {
            // Icon
            ZStack {
               Circle()
                  .fill(color.opacity(0.1))
                  .frame(width: 50, height: 50)
               
               Image(systemName: icon)
                  .font(.system(size: 20, weight: .medium))
                  .foregroundStyle(color)
            }
            
            // Content
            VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
               Text(title)
                  .font(.system(.body, design: .rounded, weight: .bold))
                  .foregroundStyle(CloveColors.primaryText)
               
               Text(description)
                  .font(.system(.subheadline, design: .rounded))
                  .foregroundStyle(CloveColors.secondaryText)
                  .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            // Play icon
            Image(systemName: "play.circle.fill")
               .font(.system(size: 24, weight: .medium))
               .foregroundStyle(color)
         }
         .padding(CloveSpacing.large)
         .background(
            RoundedRectangle(cornerRadius: CloveCorners.large)
               .fill(CloveColors.background)
               .overlay(
                  RoundedRectangle(cornerRadius: CloveCorners.large)
                     .stroke(color.opacity(0.2), lineWidth: 1)
               )
         )
         .scaleEffect(isPressed ? 0.98 : 1.0)
         .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
      }
      .buttonStyle(PlainButtonStyle())
      .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
         isPressed = pressing
      }, perform: {})
      .accessibilityLabel("\(title) tutorial")
      .accessibilityHint("Start the \(title.lowercased()) tutorial")
   }
   
   private func startTutorial() {
      let error = tutorialManager.resetTutorial(tutorial)
      
      if error == .Failure {
         return print("Failed to reset tutorial.")
      }
      
      // Haptic feedback
      let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
      impactFeedback.impactOccurred()
   }
}

struct HelpRow: View {
   let icon: String
   let text: String
   
   var body: some View {
      HStack(spacing: CloveSpacing.small) {
         Image(systemName: icon)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.shared.accent)
            .frame(width: 20)
         
         Text(text)
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(CloveColors.secondaryText)
         
         Spacer()
      }
   }
}

#Preview {
   TutorialSettingsView()
      .environment(TutorialManager.shared)
}
