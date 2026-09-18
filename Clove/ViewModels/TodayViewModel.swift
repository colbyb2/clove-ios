import SwiftUI
import Foundation
import GRDB

@MainActor
@Observable
class TodayViewModel {
   enum AutoSaveField: Hashable {
      case mood
      case painLevel
      case energyLevel
      case hydration
      case isFlareDay
      case weather
      case notes
      case medicationAdherence
      case symptomRatings
   }

   enum SaveState: Equatable {
      case saved
      case saving
      case failed
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
   private(set) var trackedSymptoms: [TrackedSymptom] = []
   private(set) var loadError: RepositoryError?
   private(set) var saveError: RepositoryError?
   private(set) var hasLoadedData = false
   private(set) var saveState: SaveState = .saved
   var isSaving: Bool { saveState == .saving }
   private var autoSaveTask: Task<Void, Never>?
   private var isLoadingLogData = false
   private var hasLoadedLogData = false
   private var loadedDate = Date()
   private var autoSaveBaseline = AutoSaveSnapshot(logData: LogData())
   private var modifiedAutoSaveFields: Set<AutoSaveField> = []

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
      logData.mood.map(CloveSymbols.mood(for:)) ?? CloveSymbols.mood
   }
   
   func load() {
      do {
         settings = try settingsRepository.loadSettings() ?? .default
      } catch {
         loadError = repositoryError(error, operation: .read, resource: "settings")
         return
      }
      loadLogData(for: selectedDate)
      if loadError == nil {
         loadYesterdayLog()
      }
   }
   
   func loadLogData(for date: Date) {
      if hasLoadedLogData,
         !Calendar.current.isDate(date, inSameDayAs: loadedDate),
         !flushPendingChanges(showFailureFeedback: true) {
         selectedDate = loadedDate
         return
      }
      if hasLoadedLogData,
         loadError == nil,
         Calendar.current.isDate(date, inSameDayAs: loadedDate) {
         selectedDate = loadedDate
         return
      }

      let previousDate = loadedDate
      let hadLoadedData = hasLoadedLogData

      let loadedLog: DailyLog?
      let loadedSymptoms: [TrackedSymptom]
      do {
         loadedLog = try logsRepository.loadLog(for: date)
         loadedSymptoms = try symptomsRepository.loadTrackedSymptoms()
      } catch {
         loadError = repositoryError(error, operation: .read, resource: "health data")
         if hadLoadedData {
            selectedDate = previousDate
         }
         return
      }

      autoSaveTask?.cancel()
      isLoadingLogData = true
      defer { isLoadingLogData = false }
      self.selectedDate = date
      loadedDate = date
      trackedSymptoms = loadedSymptoms

      // Load bowel movements for this date (externally, not in LogData)
      let bowelMovements = bowelMovementRepository.getBowelMovementsForDate(date)

      // Load cycle entry for this date (externally, not in LogData)
      loadCycleEntry(for: date)

      if let data = loadedLog {
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
      saveState = .saved
      hasLoadedLogData = true
      hasLoadedData = true
      loadError = nil
   }
   
   func loadSettings() {
      do {
         self.settings = try settingsRepository.loadSettings() ?? .default
         loadError = nil
      } catch {
         loadError = repositoryError(error, operation: .read, resource: "settings")
      }
   }
   
   func loadTrackedSymptoms() {
      do {
         trackedSymptoms = try symptomsRepository.loadTrackedSymptoms()
         syncSymptomRatingsWithTrackedSymptoms()
         loadError = nil
      } catch {
         loadError = repositoryError(error, operation: .read, resource: "tracked symptoms")
      }
   }
   
   private func syncSymptomRatingsWithTrackedSymptoms() {
      let currentTrackedSymptoms = trackedSymptoms
      let trackedSymptomIds = Set(currentTrackedSymptoms.compactMap { $0.id })
      var updatedRatings: [SymptomRatingVM] = []

      // For each tracked symptom, retain an existing answer or create an
      // explicitly unanswered control for this day.
      for symptom in currentTrackedSymptoms {
         if let existingRating = logData.symptomRatings.first(where: { $0.symptomId == symptom.id }) {
            // Keep existing rating but update name and isBinary in case they changed
            var updatedRating = existingRating
            updatedRating.symptomName = symptom.name
            updatedRating.isBinary = symptom.isBinary
            updatedRatings.append(updatedRating)
         } else {
            // Showing a tracked symptom must not invent an observation.
            updatedRatings.append(SymptomRatingVM(
               symptomId: symptom.id ?? 0,
               symptomName: symptom.name,
               ratingDouble: nil,
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
      do {
         self.yesterdayLog = try logsRepository.loadLog(for: yesterday)
      } catch {
         loadError = repositoryError(error, operation: .read, resource: "yesterday's log")
      }
   }

   func retryLoad() {
      load()
   }
   
   func saveLog(showFeedback: Bool = true) {
      // Prevent duplicate saves
      guard !isSaving else { return }
      autoSaveTask?.cancel()
      saveState = .saving

      // Extract medication names that were marked as taken
      let medicationsTaken = settings.trackMeds ?
         logData.medicationAdherence
            .filter { $0.wasTaken }
            .map { $0.medicationName } : []

      let log = DailyLog(
         date: loadedDate,
         mood: settings.trackMood ? Self.rating(from: logData.mood) : nil,
         painLevel: settings.trackPain ? Self.rating(from: logData.painLevel) : nil,
         energyLevel: settings.trackEnergy ? Self.rating(from: logData.energyLevel) : nil,
         waterIntake: settings.trackHydration && logData.waterIntake > 0 ? logData.waterIntake : nil,
         meals: settings.trackMeals ? logData.meals : [],
         activities: settings.trackActivities ? logData.activities : [],
         medicationsTaken: medicationsTaken,
         medicationAdherence: settings.trackMeds ? logData.medicationAdherence : [],
         notes: settings.trackNotes ? logData.notes : nil,
         isFlareDay: logData.isFlareDay,
         weather: settings.trackWeather ? logData.weather : nil,
         symptomRatings: settings.trackSymptoms ? logData.symptomRatings.compactMap { $0.toModel() } : []
      )

      do {
         try logsRepository.persistLog(log)
         autoSaveBaseline = AutoSaveSnapshot(logData: logData)
         modifiedAutoSaveFields.removeAll()
         saveState = .saved
         saveError = nil
         if showFeedback {
            let message = "Log saved successfully"
            toastManager.showToast(message: message, color: CloveColors.success, icon: Image(systemName: "checkmark.circle"))
         }

         // Check for rating prompt opportunity
         if showFeedback { Task {
            await AppReviewManager.shared.promptForReviewIfEligible()
         } }
      } catch {
         saveState = .failed
         saveError = repositoryError(error, operation: .write, resource: "daily log")
         if showFeedback {
            toastManager.showToast(message: "Changes couldn't be saved. Tap Retry.", color: CloveColors.error)
         }
      }

   }

   /// Schedules a save for a field the user changed after input settles.
   /// Loaded defaults are compared with the initial form snapshot and are never persisted by
   /// merely opening the Today view.
   func scheduleAutoSave(for field: AutoSaveField) {
      guard !isLoadingLogData else { return }

      if autoSaveBaseline.matches(field, in: logData) {
         modifiedAutoSaveFields.remove(field)
      } else {
         modifiedAutoSaveFields.insert(field)
      }

      autoSaveTask?.cancel()
      guard !modifiedAutoSaveFields.isEmpty else {
         saveState = .saved
         return
      }

      saveState = .saving

      autoSaveTask = Task { [weak self] in
         try? await Task.sleep(nanoseconds: 600_000_000)
         guard !Task.isCancelled else { return }
         self?.autoSaveTask = nil
         self?.saveModifiedFields()
      }
   }

   @discardableResult
   private func saveModifiedFields() -> Bool {
      guard !modifiedAutoSaveFields.isEmpty else {
         saveState = .saved
         return true
      }
      saveState = .saving

      let fieldsToSave = modifiedAutoSaveFields
      var log: DailyLog
      do {
         log = try logsRepository.loadLog(for: loadedDate) ?? DailyLog(date: loadedDate)
      } catch {
         saveState = .failed
         saveError = repositoryError(error, operation: .read, resource: "daily log before saving")
         return false
      }

      for field in fieldsToSave {
         switch field {
         case .mood:
            log.mood = settings.trackMood ? Self.rating(from: logData.mood) : nil
         case .painLevel:
            log.painLevel = settings.trackPain ? Self.rating(from: logData.painLevel) : nil
         case .energyLevel:
            log.energyLevel = settings.trackEnergy ? Self.rating(from: logData.energyLevel) : nil
         case .hydration:
            log.waterIntake = settings.trackHydration && logData.waterIntake > 0 ? logData.waterIntake : nil
         case .isFlareDay:
            log.isFlareDay = logData.isFlareDay
         case .weather:
            log.weather = settings.trackWeather ? logData.weather : nil
         case .notes:
            log.notes = settings.trackNotes ? logData.notes : nil
         case .medicationAdherence:
            let adherence = settings.trackMeds ? logData.medicationAdherence : []
            log.medicationAdherenceJSON = Self.encodeJSON(adherence)
            log.medicationsTaken = adherence.filter(\.wasTaken).map(\.medicationName)
         case .symptomRatings:
            let ratings = settings.trackSymptoms ? logData.symptomRatings.compactMap { $0.toModel() } : []
            log.symptomRatingsJSON = Self.encodeJSON(ratings)
         }
      }

      do {
         try logsRepository.persistLog(log)
         autoSaveBaseline.update(fieldsToSave, from: logData)
         modifiedAutoSaveFields.subtract(fieldsToSave)
         saveState = modifiedAutoSaveFields.isEmpty ? .saved : .saving
         saveError = nil
         return true
      } catch {
         saveState = .failed
         saveError = repositoryError(error, operation: .write, resource: "daily log")
         return false
      }
   }

   func saveHydration() {
      scheduleAutoSave(for: .hydration)
   }

   func retrySave() {
      autoSaveTask?.cancel()
      autoSaveTask = nil
      if !saveModifiedFields() {
         toastManager.showToast(message: "Still unable to save. Your changes remain on screen.", color: CloveColors.error)
      }
   }

   @discardableResult
   func flushPendingChanges(showFailureFeedback: Bool = false) -> Bool {
      autoSaveTask?.cancel()
      autoSaveTask = nil
      guard !modifiedAutoSaveFields.isEmpty else { return saveState != .failed }
      let saved = saveModifiedFields()
      if !saved, showFailureFeedback {
         toastManager.showToast(
            message: "Changes couldn't be saved. Return to Today and tap Retry.",
            color: CloveColors.error,
            icon: Image(systemName: "exclamationmark.triangle")
         )
      }
      return saved
   }

   private static func rating(from value: Double?) -> Int? {
      guard let value, value.isFinite else { return nil }
      return min(10, max(0, Int(value.rounded())))
   }

   private static func encodeJSON<Value: Encodable>(_ value: Value) -> String {
      guard let data = try? JSONEncoder().encode(value),
            let json = String(data: data, encoding: .utf8) else {
         return "[]"
      }
      return json
   }

   private func repositoryError(
      _ error: Error,
      operation: RepositoryOperation,
      resource: String
   ) -> RepositoryError {
      if let repositoryError = error as? RepositoryError {
         return repositoryError
      }
      return RepositoryError(operation: operation, resource: resource, underlyingError: error)
   }
   
   // MARK: - Symptom Management
   
   func addSymptom(name: String) {
      let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedName.isEmpty else { return }
      
      // Check if symptom already exists
      if trackedSymptoms.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
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
      if trackedSymptoms.contains(where: { $0.name.lowercased() == trimmedName.lowercased() && $0.id != id }) {
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
   var mood: Double?
   var painLevel: Double?
   var energyLevel: Double?
   var waterIntake: Int
   var isFlareDay: Bool
   var weather: String?
   var notes: String?
   var medicationAdherence: [MedicationAdherence]
   var symptomRatings: [SymptomRatingVM]

   init(logData: LogData) {
      mood = logData.mood
      painLevel = logData.painLevel
      energyLevel = logData.energyLevel
      waterIntake = logData.waterIntake
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
      case .hydration: waterIntake == logData.waterIntake
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
         case .hydration: waterIntake = logData.waterIntake
         case .isFlareDay: isFlareDay = logData.isFlareDay
         case .weather: weather = logData.weather
         case .notes: notes = logData.notes
         case .medicationAdherence: medicationAdherence = logData.medicationAdherence
         case .symptomRatings: symptomRatings = logData.symptomRatings
         }
      }
   }
}
