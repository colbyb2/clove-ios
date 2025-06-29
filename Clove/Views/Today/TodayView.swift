import SwiftUI

struct TodayView: View {
   @State var viewModel = TodayViewModel()
   
   @State private var showEditSymptoms: Bool = false
   
   var body: some View {
      ScrollView {
         VStack(alignment: .leading, spacing: 24) {
            
            // Date Navigation Header
            DateNavigationHeader() { newDate in
               self.viewModel.loadLogData(for: newDate)
            }
            
            // Yesterday's Summary (only show if data exists or it's helpful for context)
            if (viewModel.yesterdayLog != nil) {
               YesterdaySummary(
                  yesterdayLog: viewModel.yesterdayLog,
                  settings: viewModel.settings
               )
            }
            
            if viewModel.settings.trackMood {
            AccessibleRatingInput(
               value: $viewModel.logData.mood,
               label: "Mood",
               emoji: String(viewModel.currentMoodEmoji),
               maxValue: 10
            )
         }
         
         if viewModel.settings.trackPain {
            AccessibleRatingInput(
               value: $viewModel.logData.painLevel,
               label: "Pain Level",
               emoji: "🩹",
               maxValue: 10
            )
         }
         
         if viewModel.settings.trackEnergy {
            AccessibleRatingInput(
               value: $viewModel.logData.energyLevel,
               label: "Energy Level",
               emoji: "⚡",
               maxValue: 10
            )
         }
         
         if viewModel.settings.trackSymptoms {
            HStack {
               Text("Symptoms").font(.system(size: 22, weight: .semibold, design: .rounded))
               Spacer()
               Button("Edit") {
                  showEditSymptoms = true
                  // Haptic feedback
                  let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                  impactFeedback.impactOccurred()
               }
               .foregroundStyle(CloveColors.accent)
               .fontWeight(.semibold)
               .frame(minWidth: 44, minHeight: 44) // Minimum touch target
               .accessibilityLabel("Edit symptoms")
               .accessibilityHint("Opens symptoms management screen")
            }
            ForEach(viewModel.logData.symptomRatings.indices, id: \.self) { i in
               AccessibleRatingInput(
                  value: $viewModel.logData.symptomRatings[i].ratingDouble,
                  label: viewModel.logData.symptomRatings[i].symptomName,
                  emoji: "🩺",
                  maxValue: 10
               )
            }
            if (viewModel.logData.symptomRatings.isEmpty) {
               HStack {
                  Spacer()
                  Text("No Symptoms Being Tracked")
                     .font(.system(size: 18, weight: .semibold))
                     .foregroundStyle(CloveColors.secondaryText)
                  Spacer()
               }
            }
         }
         
         if viewModel.settings.showFlareToggle {
            VStack(spacing: CloveSpacing.small) {
               HStack {
                  HStack(spacing: CloveSpacing.small) {
                     Text("🔥")
                        .font(.system(size: 20))
                     Text("Flare Day")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                  }
                  
                  Spacer()
                  
                  CloveToggle(toggled: $viewModel.logData.isFlareDay, onColor: .error, handleColor: .card.opacity(0.6))
                     .accessibilityLabel("Flare day toggle")
                     .accessibilityHint(viewModel.logData.isFlareDay ? "Currently marked as flare day, tap to unmark" : "Currently not marked as flare day, tap to mark")
                     .onChange(of: viewModel.logData.isFlareDay) { _, _ in
                        // Haptic feedback for toggle
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                     }
               }
               
               if viewModel.logData.isFlareDay {
                  Text("Take care of yourself today")
                     .font(CloveFonts.small())
                     .foregroundStyle(CloveColors.secondaryText)
                     .italic()
               }
            }
            .padding(.vertical, CloveSpacing.small)
         }
         
         Button(action: {
            // Haptic feedback for save action
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            viewModel.saveLog()
            
            // Success haptic feedback (will be triggered by toast in ViewModel)
         }) {
            HStack(spacing: CloveSpacing.small) {
               Image(systemName: "checkmark.circle.fill")
                  .font(.system(size: 18, weight: .semibold))
               
               Text("Save Today's Log")
                  .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56) // Large touch target
            .background(
               RoundedRectangle(cornerRadius: CloveCorners.medium)
                  .fill(CloveColors.accent)
                  .shadow(color: CloveColors.accent.opacity(0.3), radius: 4, x: 0, y: 2)
            )
         }
         .accessibilityLabel("Save today's health log")
         .accessibilityHint("Saves all current ratings and settings")
         
//            Button("DEV - Add Logs") {
//               DEVCreateLogs.execute()
//            }
         }
         .padding()
      }
      .padding(.vertical)
      .onAppear {
         viewModel.load()
      }
      .sheet(isPresented: $showEditSymptoms) {
         EditSymptomsSheet(
            viewModel: viewModel,
            trackedSymptoms: SymptomsRepo.shared.getTrackedSymptoms()
         )
      }
   }
}

#Preview {
   NavigationStack {
      TodayView(viewModel: TodayViewModel(settings: UserSettings(trackMood: true, trackPain: true, trackEnergy: true, trackSymptoms: true, trackMeals: false, trackActivities: false, trackMeds: false, showFlareToggle: true)))
   }
}
