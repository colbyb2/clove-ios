import Foundation
import GRDB

@Observable
class HistoryCalendarViewModel {
   var logsByDate: [Date: DailyLog] = [:]
   var selectedDate: Date? = nil
   var selectedCategory: TrackingCategory = .allData
   var userSettings: UserSettings = .default
   var trackedSymptoms: [TrackedSymptom] = []
   
   let calendar = Calendar.current
   
   var monthLogs: [DailyLog] {
      logsByDate.filter { calendar.isDate($0.key, equalTo: selectedDate ?? Date(), toGranularity: .month) }.map(\.value)
   }
   
   var averageMood: Int {
      let moods = monthLogs.compactMap { $0.mood }
      return moods.isEmpty ? 0 : moods.reduce(0, +) / moods.count
   }
   
   var averagePain: Int {
      let pains = monthLogs.compactMap { $0.painLevel }
      return pains.isEmpty ? 0 : pains.reduce(0, +) / pains.count
   }
   
   // Get available tracking categories based on user settings and symptoms
   var availableCategories: [TrackingCategory] {
      var categories: [TrackingCategory] = [.allData]
      
      if userSettings.trackMood { categories.append(.mood) }
      if userSettings.trackPain { categories.append(.pain) }
      if userSettings.trackEnergy { categories.append(.energy) }
      if userSettings.trackMeals { categories.append(.meals) }
      if userSettings.trackActivities { categories.append(.activities) }
      if userSettings.trackMeds { categories.append(.medications) }
      
      // Add symptom categories
      for symptom in trackedSymptoms {
         if let symptomId = symptom.id {
            categories.append(.symptom(id: symptomId, name: symptom.name))
         }
      }
      
      return categories
   }
   
   init() {
      loadData()
   }
   
   func loadData() {
      loadLogs()
      loadUserSettings()
      loadTrackedSymptoms()
   }
   
   func loadLogs() {
      let logs = LogsRepo.shared.getLogs()
      self.logsByDate = Dictionary(uniqueKeysWithValues: logs.map { ($0.date.stripTime(), $0) })
   }
   
   func loadUserSettings() {
      self.userSettings = UserSettingsRepo.shared.getSettings() ?? .default
   }
   
   func loadTrackedSymptoms() {
      self.trackedSymptoms = SymptomsRepo.shared.getTrackedSymptoms()
   }
   
   func log(for date: Date) -> DailyLog? {
      logsByDate[date.stripTime()]
   }
}

enum TrackingCategory: Hashable, Identifiable {
   case allData
   case mood
   case pain
   case energy
   case meals
   case activities
   case medications
   case symptom(id: Int64, name: String)
   
   var id: String {
      switch self {
      case .allData: return "allData"
      case .mood: return "mood"
      case .pain: return "pain"
      case .energy: return "energy"
      case .meals: return "meals"
      case .activities: return "activities"
      case .medications: return "medications"
      case .symptom(let id, _): return "symptom_\(id)"
      }
   }
   
   var displayName: String {
      switch self {
      case .allData: return "All Data"
      case .mood: return "Mood"
      case .pain: return "Pain"
      case .energy: return "Energy"
      case .meals: return "Meals"
      case .activities: return "Activities"
      case .medications: return "Medications"
      case .symptom(_, let name): return name
      }
   }
   
   var icon: String {
      switch self {
      case .allData: return "chart.bar.fill"
      case .mood: return "face.smiling"
      case .pain: return "cross.fill"
      case .energy: return "bolt.fill"
      case .meals: return "fork.knife"
      case .activities: return "figure.walk"
      case .medications: return "pills.fill"
      case .symptom: return "stethoscope"
      }
   }
   
   var emoji: String {
      switch self {
      case .allData: return "📊"
      case .mood: return "😊"
      case .pain: return "🩹"
      case .energy: return "⚡"
      case .meals: return "🍎"
      case .activities: return "🏃"
      case .medications: return "💊"
      case .symptom: return "🩺"
      }
   }
}
