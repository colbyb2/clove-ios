import Foundation
import GRDB

@Observable
class HistoryCalendarViewModel {
   // MARK: - Dependencies
   private let daySummaryRepository: HistoryDaySummaryRepositoryProtocol
   private let settingsRepository: UserSettingsRepositoryProtocol
   private let symptomsRepository: SymptomsRepositoryProtocol
   private let cycleRepository: CycleRepositoryProtocol
   private let cycleManager: CycleManaging

   // MARK: - State
   var logsByDate: [Date: DailyLog] = [:]
   var daySummariesByDate: [Date: HistoryDaySummary] = [:]
   var bowelMovementsByDate: [Date: [BowelMovement]] = [:]
   var cyclesByDate: [Date: Cycle] = [:]
   var cyclePrediction: CyclePrediction? = nil
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
      if userSettings.trackHydration { categories.append(.hydration) }
      if userSettings.trackMeals { categories.append(.meals) }
      if userSettings.trackActivities { categories.append(.activities) }
      if userSettings.trackMeds { categories.append(.medications) }
      if userSettings.trackBowelMovements { categories.append(.bowelMovements) }
      
      // Add symptom categories
      for symptom in trackedSymptoms {
         if let symptomId = symptom.id {
            categories.append(.symptom(id: symptomId, name: symptom.name))
         }
      }
      
      return categories
   }
   
   // MARK: - Initialization

   /// Convenience initializer using production singletons
   convenience init() {
      self.init(
         daySummaryRepository: HistoryDaySummaryRepo.shared,
         settingsRepository: UserSettingsRepo.shared,
         symptomsRepository: SymptomsRepo.shared,
         cycleRepository: CycleRepo.shared,
         cycleManager: CycleManager()
      )
   }

   /// Designated initializer with full dependency injection
   init(
      daySummaryRepository: HistoryDaySummaryRepositoryProtocol,
      settingsRepository: UserSettingsRepositoryProtocol,
      symptomsRepository: SymptomsRepositoryProtocol,
      cycleRepository: CycleRepositoryProtocol,
      cycleManager: CycleManaging
   ) {
      self.daySummaryRepository = daySummaryRepository
      self.settingsRepository = settingsRepository
      self.symptomsRepository = symptomsRepository
      self.cycleRepository = cycleRepository
      self.cycleManager = cycleManager
      loadData()
   }

   /// Preview factory with mock dependencies and sample data
   static func preview(withSampleData: Bool = true) -> HistoryCalendarViewModel {
      let container = MockDependencyContainer(
         logsRepository: withSampleData ? MockLogsRepository.withSampleData(days: 30) : MockLogsRepository(),
         symptomsRepository: MockSymptomsRepository.withDefaultSymptoms()
      )
      let summaryRepository = MockHistoryDaySummaryRepository(
         logs: container.logsRepository.getLogs(),
         foodEntries: withSampleData ? MockFoodEntryRepository.withSampleData(days: 7).getAllEntries() : [],
         activityEntries: withSampleData ? MockActivityEntryRepository.withSampleData(days: 7).getAllEntries() : []
      )
      return HistoryCalendarViewModel(
         daySummaryRepository: summaryRepository,
         settingsRepository: container.settingsRepository,
         symptomsRepository: container.symptomsRepository,
         cycleRepository: container.cycleRepository,
         cycleManager: MockCycleManager()
      )
   }
   
   func loadData() {
      loadDaySummaries()
      loadCycles()
      loadUserSettings()
      loadTrackedSymptoms()
      loadCyclePrediction()
   }

   func loadDaySummaries() {
      daySummariesByDate = daySummaryRepository.getDaySummaries()
      logsByDate = daySummariesByDate.compactMapValues(\.log)
      bowelMovementsByDate = daySummariesByDate.compactMapValues { summary in
         summary.bowelMovements.isEmpty ? nil : summary.bowelMovements
      }
   }

   func loadCycles() {
      let cycles = cycleRepository.getAllCycles()
      // Use merging initializer to handle duplicate dates - keep the most recent entry (last one)
      self.cyclesByDate = Dictionary(cycles.map { ($0.date.stripTime(), $0) }, uniquingKeysWith: { _, last in last })
   }

   func loadUserSettings() {
      self.userSettings = settingsRepository.getSettings() ?? .default
   }

   func loadTrackedSymptoms() {
      self.trackedSymptoms = symptomsRepository.getTrackedSymptoms()
   }

   func loadCyclePrediction() {
      // Only load prediction if cycle tracking is enabled
      if userSettings.trackCycle {
         self.cyclePrediction = cycleManager.getNextCycle()
      } else {
         self.cyclePrediction = nil
      }
   }
   
   func log(for date: Date) -> DailyLog? {
      logsByDate[date.stripTime()]
   }

   func bowelMovements(for date: Date) -> [BowelMovement] {
      bowelMovementsByDate[date.stripTime()] ?? []
   }

   func hasMeals(for date: Date) -> Bool {
      daySummariesByDate[date.stripTime()]?.hasMeals ?? false
   }

   func hasActivities(for date: Date) -> Bool {
      daySummariesByDate[date.stripTime()]?.hasActivities ?? false
   }

   func hasAnyData(for date: Date) -> Bool {
      daySummariesByDate[date.stripTime()]?.hasAnyData ?? false
   }
}

enum TrackingCategory: Hashable, Identifiable {
   case allData
   case mood
   case pain
   case energy
   case hydration
   case meals
   case activities
   case medications
   case bowelMovements
   case symptom(id: Int64, name: String)
   
   var id: String {
      switch self {
      case .allData: return "allData"
      case .mood: return "mood"
      case .pain: return "pain"
      case .energy: return "energy"
      case .hydration: return "hydration"
      case .meals: return "meals"
      case .activities: return "activities"
      case .medications: return "medications"
      case .bowelMovements: return "bowelMovements"
      case .symptom(let id, _): return "symptom_\(id)"
      }
   }
   
   var displayName: String {
      switch self {
      case .allData: return "All Data"
      case .mood: return "Mood"
      case .pain: return "Pain"
      case .energy: return "Energy"
      case .hydration: return "Hydration"
      case .meals: return "Meals"
      case .activities: return "Activities"
      case .medications: return "Medications"
      case .bowelMovements: return "Bowel Movements"
      case .symptom(_, let name): return name
      }
   }
   
   var icon: String {
      switch self {
      case .allData: return "chart.bar.fill"
      case .mood: return "face.smiling"
      case .pain: return "cross.fill"
      case .energy: return "bolt.fill"
      case .hydration: return "drop.fill"
      case .meals: return "fork.knife"
      case .activities: return "figure.walk"
      case .medications: return "pills.fill"
      case .bowelMovements: return "figure.seated.side"
      case .symptom: return "stethoscope"
      }
   }
   
}
