import SwiftUI
import Foundation
import GRDB

@Observable
class TodayViewModel {
   enum AutoSaveField: Hashable {
      case mood
      case painLevel
      case energyLevel
      case isFlareDay
      case weather
      case notes
      case medicationAdherence
      case symptomRatings
   }

   // MARK: - Dependencies
   private let logsRepository: LogsRepositoryProtocol
   private let symptomsRepository: SymptomsRepositoryProtocol
   private let settingsRepository: UserSettingsRepositoryProtocol
   private let medicationRepository: MedicationRepositoryProtocol
   private let bowelMovementRepository: BowelMovementRepositoryProtocol
   private let cycleRepository: CycleRepositoryProtocol
   private let toastManager: ToastManaging

   // MARK: - State
   var settings: UserSettings = .default

   var selectedDate: Date = Date()
   var logData: LogData = LogData()

   var yesterdayLog: DailyLog? = nil
   var cycleEntry: Cycle? = nil
   var isSaving = false
   private var autoSaveTask: Task<Void, Never>?
   private var isLoadingLogData = false
   private var autoSaveBaseline = AutoSaveSnapshot(logData: LogData())
   private var modifiedAutoSaveFields: Set<AutoSaveField> = []

   private var isAutoSaveEnabled: Bool {
      settingsRepository.getSettings()?.autoSaveEnabled ?? true
   }

   // MARK: - Initialization

   /// Convenience initializer using production singletons
   convenience init() {
      self.init(
         logsRepository: LogsRepo.shared,
         symptomsRepository: SymptomsRepo.shared,
         settingsRepository: UserSettingsRepo.shared,
         medicationRepository: MedicationRepository.shared,
         bowelMovementRepository: BowelMovementRepo.shared,
         cycleRepository: CycleRepo.shared,
         toastManager: ToastManager.shared
      )
   }

   /// Designated initializer with full dependency injection
   init(
      logsRepository: LogsRepositoryProtocol,
      symptomsRepository: SymptomsRepositoryProtocol,
      settingsRepository: UserSettingsRepositoryProtocol,
      medicationRepository: MedicationRepositoryProtocol,
      bowelMovementRepository: BowelMovementRepositoryProtocol,
      cycleRepository: CycleRepositoryProtocol,
      toastManager: ToastManaging
   ) {
      self.logsRepository = logsRepository
      self.symptomsRepository = symptomsRepository
      self.settingsRepository = settingsRepository
      self.medicationRepository = medicationRepository
      self.bowelMovementRepository = bowelMovementRepository
      self.cycleRepository = cycleRepository
      self.toastManager = toastManager
   }

   /// Preview factory with mock dependencies and configurable state
   static func preview(
      settings: UserSettings = .default,
      logData: LogData? = nil
   ) -> TodayViewModel {
      let container = MockDependencyContainer()
      let vm = TodayViewModel(
         logsRepository: container.logsRepository,
         symptomsRepository: container.symptomsRepository,
         settingsRepository: container.settingsRepository,
         medicationRepository: container.medicationRepository,
         bowelMovementRepository: container.bowelMovementRepository,
         cycleRepository: container.cycleRepository,
         toastManager: container.toastManager
      )
      vm.settings = settings
      if let data = logData {
         vm.logData = data
      }
      return vm
   }
   
   var currentMoodSymbol: String {
      CloveSymbols.mood(for: logData.mood)
   }
   
   func load() {
      loadSettings()
      loadTrackedSymptoms()
      loadLogData(for: selectedDate)
      loadYesterdayLog()
   }
   
   func loadLogData(for date: Date) {
      autoSaveTask?.cancel()
      isLoadingLogData = true
      defer { isLoadingLogData = false }
      self.selectedDate = date

      // Load bowel movements for this date (externally, not in LogData)
      let bowelMovements = bowelMovementRepository.getBowelMovementsForDate(date)

      // Load cycle entry for this date (externally, not in LogData)
      loadCycleEntry(for: date)

      if let data = logsRepository.getLogForDate(date) {
         self.logData = LogData(from: data, bowelMovements: bowelMovements)
      } else {
         // No existing data for this date, create new LogData with default values
         self.logData = LogData()
         self.logData.bowelMovements = bowelMovements
      }

      // Ensure symptom ratings match current tracked symptoms
      syncSymptomRatingsWithTrackedSymptoms()

      // Ensure medication adherence matches current tracked medications
      syncMedicationAdherenceWithTrackedMedications()

      // Form defaults and tracked-item synchronization are display state, not user edits.
      autoSaveBaseline = AutoSaveSnapshot(logData: logData)
      modifiedAutoSaveFields.removeAll()
   }
   
   func loadSettings() {
      self.settings = settingsRepository.getSettings() ?? .default
   }
   
   func loadTrackedSymptoms() {
      syncSymptomRatingsWithTrackedSymptoms()
   }
   
   private func syncSymptomRatingsWithTrackedSymptoms() {
      let currentTrackedSymptoms = symptomsRepository.getTrackedSymptoms()
      let trackedSymptomIds = Set(currentTrackedSymptoms.compactMap { $0.id })
      var updatedRatings: [SymptomRatingVM] = []

      // For each currently tracked symptom, find existing rating or create default
      for symptom in currentTrackedSymptoms {
         if let existingRating = logData.symptomRatings.first(where: { $0.symptomId == symptom.id }) {
            // Keep existing rating but update name and isBinary in case they changed
            var updatedRating = existingRating
            updatedRating.symptomName = symptom.name
            updatedRating.isBinary = symptom.isBinary
            updatedRatings.append(updatedRating)
         } else {
            // Create new rating with default value
            updatedRatings.append(SymptomRatingVM(
               symptomId: symptom.id ?? 0,
               symptomName: symptom.name,
               ratingDouble: 5,
               isBinary: symptom.isBinary
            ))
         }
      }

      // Keep any one-time symptoms (symptoms not in the tracked symptoms list)
      let oneTimeSymptoms = logData.symptomRatings.filter { !trackedSymptomIds.contains($0.symptomId) }
      updatedRatings.append(contentsOf: oneTimeSymptoms)

      self.logData.symptomRatings = updatedRatings
   }
   
   private func syncMedicationAdherenceWithTrackedMedications() {
      let currentTrackedMedications = medicationRepository.getTrackedMedications()
      var updatedAdherence: [MedicationAdherence] = []
      
      // For each currently tracked medication, find existing adherence or create default
      for medication in currentTrackedMedications {
         guard let medicationId = medication.id else { continue }
         
         if let existingAdherence = logData.medicationAdherence.first(where: { $0.medicationId == medicationId }) {
            // Keep existing adherence but update name in case it changed
            var updatedMedicationAdherence = existingAdherence
            updatedMedicationAdherence.medicationName = medication.name
            updatedMedicationAdherence.isAsNeeded = medication.isAsNeeded
            updatedAdherence.append(updatedMedicationAdherence)
         } else {
            // Create new adherence with default value (not taken)
            updatedAdherence.append(MedicationAdherence(
               medicationId: medicationId,
               medicationName: medication.name,
               wasTaken: false,
               isAsNeeded: medication.isAsNeeded
            ))
         }
      }
      
      // Keep any one-time medications (medicationId == -1)
      let oneTimeMedications = logData.medicationAdherence.filter { $0.medicationId == -1 }
      updatedAdherence.append(contentsOf: oneTimeMedications)
      
      self.logData.medicationAdherence = updatedAdherence
   }
   
   func loadYesterdayLog() {
      let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
      self.yesterdayLog = logsRepository.getLogForDate(yesterday)
   }
   
   func saveLog(showFeedback: Bool = true) {
      // Prevent duplicate saves
      guard !isSaving else { return }
      autoSaveTask?.cancel()
      isSaving = true

      // Extract medication names that were marked as taken
      let medicationsTaken = settings.trackMeds ?
         logData.medicationAdherence
            .filter { $0.wasTaken }
            .map { $0.medicationName } : []

      let log = DailyLog(
         date: selectedDate,
         mood: settings.trackMood ? Int(logData.mood) : nil,
         painLevel: settings.trackPain ? Int(logData.painLevel) : nil,
         energyLevel: settings.trackEnergy ? Int(logData.energyLevel) : nil,
         waterIntake: settings.trackHydration && logData.waterIntake > 0 ? logData.waterIntake : nil,
         meals: settings.trackMeals ? logData.meals : [],
         activities: settings.trackActivities ? logData.activities : [],
         medicationsTaken: medicationsTaken,
         medicationAdherence: settings.trackMeds ? logData.medicationAdherence : [],
         notes: settings.trackNotes ? logData.notes : nil,
         isFlareDay: logData.isFlareDay,
         weather: settings.trackWeather ? logData.weather : nil,
         symptomRatings: settings.trackSymptoms ? logData.symptomRatings.map { $0.toModel() } : []
      )

      let result = logsRepository.saveLog(log)
      isSaving = false

      if result {
         MetricRegistry.shared.invalidateCache()
         autoSaveBaseline = AutoSaveSnapshot(logData: logData)
         modifiedAutoSaveFields.removeAll()
         if showFeedback {
            let message = "Log saved successfully"
            toastManager.showToast(message: message, color: CloveColors.success, icon: Image(systemName: "checkmark.circle"))
         }

         // Check for rating prompt opportunity
         if showFeedback { Task {
            await AppReviewManager.shared.promptForReviewIfEligible()
         } }
      } else if showFeedback {
         toastManager.showToast(message: "Hmm, something went wrong.", color: CloveColors.error)
      }

   }

   /// Schedules a save for a field the user changed after input settles.
   /// Loaded defaults are compared with the initial form snapshot and are never persisted by
   /// merely opening the Today view.
   func scheduleAutoSave(for field: AutoSaveField) {
      guard !isLoadingLogData, isAutoSaveEnabled else { return }

      if autoSaveBaseline.matches(field, in: logData) {
         modifiedAutoSaveFields.remove(field)
      } else {
         modifiedAutoSaveFields.insert(field)
      }

      autoSaveTask?.cancel()
      guard !modifiedAutoSaveFields.isEmpty else { return }

      autoSaveTask = Task { [weak self] in
         try? await Task.sleep(nanoseconds: 600_000_000)
         guard !Task.isCancelled else { return }
         self?.autoSaveTask = nil
         guard self?.isAutoSaveEnabled == true else { return }
         self?.saveModifiedFields()
      }
   }

   private func saveModifiedFields() {
      guard !isSaving, !modifiedAutoSaveFields.isEmpty else { return }
      isSaving = true

      let fieldsToSave = modifiedAutoSaveFields
      var log = logsRepository.getLogForDate(selectedDate) ?? DailyLog(date: selectedDate)

      for field in fieldsToSave {
         switch field {
         case .mood:
            log.mood = settings.trackMood ? Int(logData.mood) : nil
         case .painLevel:
            log.painLevel = settings.trackPain ? Int(logData.painLevel) : nil
         case .energyLevel:
            log.energyLevel = settings.trackEnergy ? Int(logData.energyLevel) : nil
         case .isFlareDay:
            log.isFlareDay = logData.isFlareDay
         case .weather:
            log.weather = settings.trackWeather ? logData.weather : nil
         case .notes:
            log.notes = settings.trackNotes ? logData.notes : nil
         case .medicationAdherence:
            let adherence = settings.trackMeds ? logData.medicationAdherence : []
            log.medicationAdherenceJSON = try! JSONEncoder().encode(adherence).toJSONString()
            log.medicationsTaken = adherence.filter(\.wasTaken).map(\.medicationName)
         case .symptomRatings:
            let ratings = settings.trackSymptoms ? logData.symptomRatings.map { $0.toModel() } : []
            log.symptomRatingsJSON = try! JSONEncoder().encode(ratings).toJSONString()
         }
      }

      let result = logsRepository.saveLog(log)
      isSaving = false

      if result {
         MetricRegistry.shared.invalidateCache()
         autoSaveBaseline.update(fieldsToSave, from: logData)
         modifiedAutoSaveFields.subtract(fieldsToSave)
      }
   }

   func saveHydration() {
      guard isAutoSaveEnabled else { return }
      let ounces = logData.waterIntake > 0 ? logData.waterIntake : nil
      if logsRepository.saveWaterIntake(ounces, for: selectedDate) {
         MetricRegistry.shared.invalidateCache()
      } else {
         toastManager.showToast(message: "Hydration couldn't be saved.", color: CloveColors.error)
      }
   }
   
   // MARK: - Symptom Management
   
   func addSymptom(name: String) {
      let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedName.isEmpty else { return }
      
      // Check if symptom already exists
      if symptomsRepository.getTrackedSymptoms().contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
         toastManager.showToast(message: "Symptom already exists", color: CloveColors.error, icon: Image(systemName: "exclamationmark.triangle"))
         return
      }
      
      let symptom = TrackedSymptom(name: trimmedName)
      let success = symptomsRepository.saveSymptom(symptom)
      
      if success {
         loadTrackedSymptoms() // Refresh the list
         toastManager.showToast(message: "Symptom added successfully", color: CloveColors.success, icon: Image(systemName: "checkmark.circle"))
      } else {
         toastManager.showToast(message: "Failed to add symptom", color: CloveColors.error)
      }
   }
   
   func updateSymptom(id: Int64, newName: String, isBinary: Bool) {
      let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedName.isEmpty else { return }

      // Check if another symptom already has this name
      if symptomsRepository.getTrackedSymptoms().contains(where: { $0.name.lowercased() == trimmedName.lowercased() && $0.id != id }) {
         toastManager.showToast(message: "Symptom name already exists", color: CloveColors.error, icon: Image(systemName: "exclamationmark.triangle"))
         return
      }

      let success = symptomsRepository.updateSymptom(id: id, name: trimmedName, isBinary: isBinary)

      if success {
         loadTrackedSymptoms() // Refresh the list
         toastManager.showToast(message: "Symptom updated successfully", color: CloveColors.success, icon: Image(systemName: "checkmark.circle"))
      } else {
         toastManager.showToast(message: "Failed to update symptom", color: CloveColors.error)
      }
   }
   
   func deleteSymptom(id: Int64) {
      let success = symptomsRepository.deleteSymptom(id: id)

      if success {
         loadTrackedSymptoms() // Refresh the list
         toastManager.showToast(message: "Symptom deleted", color: CloveColors.success, icon: Image(systemName: "checkmark.circle"))
      } else {
         toastManager.showToast(message: "Failed to delete symptom", color: CloveColors.error)
      }
   }

   // MARK: - Cycle Management

   func loadCycleEntry(for date: Date) {
      let entries = cycleRepository.getCyclesForDate(date)
      self.cycleEntry = entries.first
   }

   func deleteCycleEntry() {
      guard let id = cycleEntry?.id else { return }
      if cycleRepository.delete(id: id) {
         cycleEntry = nil
         toastManager.showToast(
            message: "Cycle entry deleted",
            color: CloveColors.success,
            icon: Image(systemName: "checkmark.circle")
         )
      } else {
         toastManager.showToast(
            message: "Failed to delete cycle entry",
            color: CloveColors.error
         )
      }
   }
}

private struct AutoSaveSnapshot {
   var mood: Double
   var painLevel: Double
   var energyLevel: Double
   var isFlareDay: Bool
   var weather: String?
   var notes: String?
   var medicationAdherence: [MedicationAdherence]
   var symptomRatings: [SymptomRatingVM]

   init(logData: LogData) {
      mood = logData.mood
      painLevel = logData.painLevel
      energyLevel = logData.energyLevel
      isFlareDay = logData.isFlareDay
      weather = logData.weather
      notes = logData.notes
      medicationAdherence = logData.medicationAdherence
      symptomRatings = logData.symptomRatings
   }

   func matches(_ field: TodayViewModel.AutoSaveField, in logData: LogData) -> Bool {
      switch field {
      case .mood: mood == logData.mood
      case .painLevel: painLevel == logData.painLevel
      case .energyLevel: energyLevel == logData.energyLevel
      case .isFlareDay: isFlareDay == logData.isFlareDay
      case .weather: weather == logData.weather
      case .notes: notes == logData.notes
      case .medicationAdherence: medicationAdherence == logData.medicationAdherence
      case .symptomRatings: symptomRatings == logData.symptomRatings
      }
   }

   mutating func update(_ fields: Set<TodayViewModel.AutoSaveField>, from logData: LogData) {
      for field in fields {
         switch field {
         case .mood: mood = logData.mood
         case .painLevel: painLevel = logData.painLevel
         case .energyLevel: energyLevel = logData.energyLevel
         case .isFlareDay: isFlareDay = logData.isFlareDay
         case .weather: weather = logData.weather
         case .notes: notes = logData.notes
         case .medicationAdherence: medicationAdherence = logData.medicationAdherence
         case .symptomRatings: symptomRatings = logData.symptomRatings
         }
      }
   }
}
