import GRDB

struct UserSettings: Codable, FetchableRecord, PersistableRecord, Identifiable {
   var id: Int64? = 1 // always ID 1 (singleton row)
   
   var trackMood: Bool
   var trackPain: Bool
   var trackEnergy: Bool
   var trackSymptoms: Bool
   var trackMeals: Bool
   var trackActivities: Bool
   var trackMeds: Bool
   var showFlareToggle: Bool
   var trackWeather: Bool
}

extension UserSettings {
   /// Default settings configuration
   static let `default` = UserSettings(
      trackMood: true,
      trackPain: false,
      trackEnergy: true,
      trackSymptoms: true,
      trackMeals: false,
      trackActivities: false,
      trackMeds: false,
      showFlareToggle: true,
      trackWeather: true
   )
   
   /// Blank settings
   static let blank = UserSettings(
      trackMood: false,
      trackPain: false,
      trackEnergy: false,
      trackSymptoms: false,
      trackMeals: false,
      trackActivities: false,
      trackMeds: false,
      showFlareToggle: false,
      trackWeather: false
   )
}

extension UserSettings {
   func isSomeEnabled() -> Bool {
      return trackMood || trackPain || trackEnergy || trackSymptoms || trackMeals || trackActivities || trackMeds || showFlareToggle || trackWeather
   }
}
