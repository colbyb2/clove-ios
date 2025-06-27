import SwiftUI
import Foundation
import GRDB

@Observable
class TodayViewModel {
   var settings: UserSettings = .default
   var mood: Double = 5
   var painLevel: Double = 5
   var energyLevel: Double = 5
   var isFlareDay: Bool = false
   var symptomRatings: [SymptomRatingVM] = []
   
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
         if range.contains(mood) {
            return emoji
         }
      }
      return "❔"
   }
   
   func load() {
      guard !mocked else { return }
      loadSettings()
      loadTrackedSymptoms()
   }
   
   func loadSettings() {
      self.settings = UserSettingsRepo.shared.getSettings() ?? .default
   }
   
   func loadTrackedSymptoms() {
      let trackedSymptoms = SymptomsRepo.shared.getTrackedSymptoms()
      self.symptomRatings = trackedSymptoms.map { SymptomRatingVM(symptomName: $0.name, ratingDouble: 5) }
   }
   
   func saveLog() {
      let log = DailyLog(
         date: Date(),
         mood: settings.trackMood ? Int(mood) : nil,
         painLevel: settings.trackPain ? Int(painLevel) : nil,
         energyLevel: settings.trackEnergy ? Int(energyLevel) : nil,
         meals: [],
         activities: [],
         medicationsTaken: [],
         notes: nil,
         isFlareDay: isFlareDay,
         symptomRatings: symptomRatings.map { $0.toModel() }
      )
      
      let result = LogsRepo.shared.saveLog(log)
      if result {
         ToastManager.shared.showToast(message: "Log saved successfully", color: CloveColors.success, icon: Image(systemName: "checkmark.circle"))
      } else {
         ToastManager.shared.showToast(message: "Hmm, something went wrong.", color: CloveColors.error)
      }
   }
}
