import SwiftUI
import Foundation
import GRDB

@Observable
class TodayViewModel {
   var settings: UserSettings = .default
   
   var selectedDate: Date = Date()
   var logData: LogData = LogData()
   
   var yesterdayLog: DailyLog? = nil
   var isSaving = false
   
   private var mocked: Bool = false
   
   init() {}
   
   init(settings: UserSettings) {
      self.mocked = true
      self.settings = settings
   }
   
   let moodEmojiMap: [ClosedRange<Double>: Character] = [
      0.0...2.0: "😢",
      2.1...4.0: "😕",
      4.1...6.0: "😐",
      6.1...8.0: "🙂",
      8.1...10.0: "😁"
   ]
   
   var currentMoodEmoji: Character {
      for (range, emoji) in moodEmojiMap {
         if range.contains(logData.mood) {
            return emoji
         }
      }
      return "❔"
   }
   
   func load() {
      guard !mocked else { return }
      loadSettings()
      loadTrackedSymptoms()
      loadLogData(for: Date())
      loadYesterdayLog()
   }
   
   func loadLogData(for date: Date) {
      self.selectedDate = date
      if let data = LogsRepo.shared.getLogForDate(date) {
         self.logData = LogData(from: data)
      } else {
         // No existing data for this date, create new LogData with default values
         self.logData = LogData()
      }
      
      // Ensure symptom ratings match current tracked symptoms
      syncSymptomRatingsWithTrackedSymptoms()
   }
   
   func loadSettings() {
      self.settings = UserSettingsRepo.shared.getSettings() ?? .default
   }
   
   func loadTrackedSymptoms() {
      let trackedSymptoms = SymptomsRepo.shared.getTrackedSymptoms()
      self.logData.symptomRatings = trackedSymptoms.map {
         return SymptomRatingVM(symptomId: $0.id ?? 0, symptomName: $0.name, ratingDouble: 5)
      }
   }
   
   private func syncSymptomRatingsWithTrackedSymptoms() {
      let currentTrackedSymptoms = SymptomsRepo.shared.getTrackedSymptoms()
      var updatedRatings: [SymptomRatingVM] = []
      
      // For each currently tracked symptom, find existing rating or create default
      for symptom in currentTrackedSymptoms {
         if let existingRating = logData.symptomRatings.first(where: { $0.symptomId == symptom.id }) {
            // Keep existing rating but update name in case it changed
            var updatedRating = existingRating
            updatedRating.symptomName = symptom.name
            updatedRatings.append(updatedRating)
         } else {
            // Create new rating with default value
            updatedRatings.append(SymptomRatingVM(
               symptomId: symptom.id ?? 0,
               symptomName: symptom.name,
               ratingDouble: 5
            ))
         }
      }
      
      self.logData.symptomRatings = updatedRatings
   }
   
   func loadYesterdayLog() {
      let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
      self.yesterdayLog = LogsRepo.shared.getLogForDate(yesterday)
   }
   
   func saveLog() {
      Task {
         await MainActor.run { isSaving = true }
         
         // Get weather data if saving for today
         let weatherData = await getWeatherDataIfToday()
         
         let log = DailyLog(
            date: selectedDate,
            mood: settings.trackMood ? Int(logData.mood) : nil,
            painLevel: settings.trackPain ? Int(logData.painLevel) : nil,
            energyLevel: settings.trackEnergy ? Int(logData.energyLevel) : nil,
            meals: [],
            activities: [],
            medicationsTaken: [],
            notes: nil,
            isFlareDay: logData.isFlareDay,
            weather: weatherData,
            symptomRatings: logData.symptomRatings.map { $0.toModel() }
         )
         
         await MainActor.run {
            let result = LogsRepo.shared.saveLog(log)
            isSaving = false
            
            if result {
               var message = "Log saved successfully"
               if weatherData != nil {
                  message += " with weather data"
               }
               ToastManager.shared.showToast(message: message, color: CloveColors.success, icon: Image(systemName: "checkmark.circle"))
            } else {
               ToastManager.shared.showToast(message: "Hmm, something went wrong.", color: CloveColors.error)
            }
         }
      }
   }
   
   private func getWeatherDataIfToday() async -> String? {
      // Only fetch weather for today's date, not for past dates
      let calendar = Calendar.current
      guard calendar.isDateInToday(selectedDate) else {
         return nil
      }
      
      // Check if weather tracking is enabled
      guard settings.trackWeather else {
         return nil
      }
      
      // Fetch current weather
      return await WeatherManager.shared.getCurrentWeatherString()
   }
   
   // MARK: - Symptom Management
   
   func addSymptom(name: String) {
      let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedName.isEmpty else { return }
      
      // Check if symptom already exists
      if SymptomsRepo.shared.getTrackedSymptoms().contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
         ToastManager.shared.showToast(message: "Symptom already exists", color: CloveColors.error, icon: Image(systemName: "exclamationmark.triangle"))
         return
      }
      
      let symptom = TrackedSymptom(name: trimmedName)
      let success = SymptomsRepo.shared.saveSymptom(symptom)
      
      if success {
         loadTrackedSymptoms() // Refresh the list
         ToastManager.shared.showToast(message: "Symptom added successfully", color: CloveColors.success, icon: Image(systemName: "checkmark.circle"))
      } else {
         ToastManager.shared.showToast(message: "Failed to add symptom", color: CloveColors.error)
      }
   }
   
   func updateSymptom(id: Int64, newName: String) {
      let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedName.isEmpty else { return }
      
      // Check if another symptom already has this name
      if SymptomsRepo.shared.getTrackedSymptoms().contains(where: { $0.name.lowercased() == trimmedName.lowercased() && $0.id != id }) {
         ToastManager.shared.showToast(message: "Symptom name already exists", color: CloveColors.error, icon: Image(systemName: "exclamationmark.triangle"))
         return
      }
      
      let success = SymptomsRepo.shared.updateSymptom(id: id, name: trimmedName)
      
      if success {
         loadTrackedSymptoms() // Refresh the list
         ToastManager.shared.showToast(message: "Symptom updated successfully", color: CloveColors.success, icon: Image(systemName: "checkmark.circle"))
      } else {
         ToastManager.shared.showToast(message: "Failed to update symptom", color: CloveColors.error)
      }
   }
   
   func deleteSymptom(id: Int64) {
      let success = SymptomsRepo.shared.deleteSymptom(id: id)
      
      if success {
         loadTrackedSymptoms() // Refresh the list
         ToastManager.shared.showToast(message: "Symptom deleted", color: CloveColors.success, icon: Image(systemName: "checkmark.circle"))
      } else {
         ToastManager.shared.showToast(message: "Failed to delete symptom", color: CloveColors.error)
      }
   }
}
