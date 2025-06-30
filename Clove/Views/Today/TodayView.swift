import SwiftUI

struct TodayView: View {
   @State var viewModel = TodayViewModel()
   
   @State private var showEditSymptoms: Bool = false
   @State private var showWeatherSelection: Bool = false
   @State private var showMedicationSelection: Bool = false
   
   var body: some View {
      ScrollView {
         VStack(alignment: .leading, spacing: 24) {
            
            // Date Navigation Header
            DateNavigationHeader() { newDate in
               self.viewModel.loadLogData(for: newDate)
            }
            
            // Yesterday's Summary (only show if data exists or it's helpful for context)
            if (viewModel.yesterdayLog != nil && Calendar.current.isDateInToday(viewModel.selectedDate)) {
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
         
         if viewModel.settings.trackWeather {
            VStack(spacing: CloveSpacing.small) {
               HStack {
                  HStack(spacing: CloveSpacing.small) {
                     Text(weatherEmoji(for: viewModel.logData.weather))
                        .font(.system(size: 20))
                     Text("Weather")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                  }
                  
                  Spacer()
                  
                  Button(action: {
                     showWeatherSelection = true
                     // Haptic feedback
                     let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                     impactFeedback.impactOccurred()
                  }) {
                     HStack {
                        Text(viewModel.logData.weather ?? "Tap to select")
                           .foregroundStyle(viewModel.logData.weather != nil ? CloveColors.primary : CloveColors.secondaryText)
                           .font(.system(.body, design: .rounded).weight(.medium))
                        
                        if viewModel.logData.weather == nil {
                           Image(systemName: "plus.circle.fill")
                              .foregroundStyle(CloveColors.accent)
                              .font(.system(size: 16))
                        }
                     }
                     .padding(.horizontal, 12)
                     .padding(.vertical, 8)
                     .background(CloveColors.card)
                     .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
                     .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
                  }
                  .accessibilityLabel("Weather selection")
                  .accessibilityHint("Opens weather selection dialog")
               }
            }
            .padding(.vertical, CloveSpacing.small)
         }
         
         if viewModel.settings.trackMeals {
            TagInputView(
               title: "Meals",
               placeholder: "Add a meal...",
               type: .meals,
               color: .green,
               items: $viewModel.logData.meals
            )
            .padding(.vertical, CloveSpacing.small)
         }
         
         if viewModel.settings.trackActivities {
            TagInputView(
               title: "Activities",
               placeholder: "Add an activity...",
               type: .activities,
               color: .blue,
               items: $viewModel.logData.activities
            )
            .padding(.vertical, CloveSpacing.small)
         }
         
         if viewModel.settings.trackMeds {
            VStack(spacing: CloveSpacing.small) {
               HStack {
                  HStack(spacing: CloveSpacing.small) {
                     Text("💊")
                        .font(.system(size: 20))
                     Text("Medications")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                  }
                  
                  Spacer()
                  
                  Button(action: {
                     showMedicationSelection = true
                     // Haptic feedback
                     let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                     impactFeedback.impactOccurred()
                  }) {
                     HStack {
                        Text(medicationSummaryText())
                           .foregroundStyle(viewModel.logData.medicationAdherence.isEmpty ? CloveColors.secondaryText : CloveColors.primary)
                           .font(.system(.body, design: .rounded).weight(.medium))
                        
                        if viewModel.logData.medicationAdherence.isEmpty {
                           Image(systemName: "plus.circle.fill")
                              .foregroundStyle(CloveColors.accent)
                              .font(.system(size: 16))
                        }
                     }
                     .padding(.horizontal, 12)
                     .padding(.vertical, 8)
                     .background(CloveColors.card)
                     .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
                     .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
                  }
                  .accessibilityLabel("Medication tracking")
                  .accessibilityHint("Opens medication checklist")
               }
            }
            .padding(.vertical, CloveSpacing.small)
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
               if viewModel.isSaving {
                  ProgressView()
                     .scaleEffect(0.9)
                     .progressViewStyle(CircularProgressViewStyle(tint: .white))
               } else {
                  Image(systemName: "checkmark.circle.fill")
                     .font(.system(size: 18, weight: .semibold))
               }
               
               Text(viewModel.isSaving ? "Saving..." : "Save Today's Log")
                  .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56) // Large touch target
            .background(
               RoundedRectangle(cornerRadius: CloveCorners.medium)
                  .fill(viewModel.isSaving ? CloveColors.secondaryText : CloveColors.accent)
                  .shadow(color: CloveColors.accent.opacity(0.3), radius: 4, x: 0, y: 2)
            )
         }
         .disabled(viewModel.isSaving)
         .accessibilityLabel(viewModel.isSaving ? "Saving health log" : "Save today's health log")
         .accessibilityHint(viewModel.isSaving ? "Currently saving with weather data" : "Saves all current ratings and settings")
         
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
      .sheet(isPresented: $showWeatherSelection) {
         WeatherSelectionSheet(selectedWeather: $viewModel.logData.weather)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
      }
      .sheet(isPresented: $showMedicationSelection) {
         MedicationSelectionSheet(medicationAdherence: $viewModel.logData.medicationAdherence)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
      }
   }
   
   private func weatherEmoji(for weather: String?) -> String {
      switch weather {
      case "Sunny": return "☀️"
      case "Cloudy": return "☁️"
      case "Rainy": return "🌧️"
      case "Stormy": return "⛈️"
      case "Snow": return "❄️"
      case "Gloomy": return "🌫️"
      default: return "🌤️"
      }
   }
   
   private func medicationSummaryText() -> String {
      let adherence = viewModel.logData.medicationAdherence
      if adherence.isEmpty {
         return "Tap to track"
      }
      
      let takenCount = adherence.filter { $0.wasTaken }.count
      let totalCount = adherence.count
      
      if takenCount == 0 {
         return "None taken yet"
      } else if takenCount == totalCount {
         return "All taken (\(totalCount))"
      } else {
         return "\(takenCount) of \(totalCount) taken"
      }
   }
}

#Preview {
   NavigationStack {
      TodayView(viewModel: TodayViewModel(settings: UserSettings(trackMood: true, trackPain: true, trackEnergy: true, trackSymptoms: true, trackMeals: false, trackActivities: false, trackMeds: false, showFlareToggle: true, trackWeather: false)))
   }
}
