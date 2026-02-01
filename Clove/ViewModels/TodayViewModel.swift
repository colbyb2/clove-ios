import SwiftUI
import Foundation
import GRDB

@Observable
class TodayViewModel {
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
      loadSettings()
      loadTrackedSymptoms()
      loadLogData(for: selectedDate)
      loadYesterdayLog()
   }
   
   func loadLogData(for date: Date) {
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
   }
   
   func loadSettings() {
      self.settings = settingsRepository.getSettings() ?? .default
   }
   
   func loadTrackedSymptoms() {
      let trackedSymptoms = symptomsRepository.getTrackedSymptoms()
      self.logData.symptomRatings = trackedSymptoms.map {
         return SymptomRatingVM(symptomId: $0.id ?? 0, symptomName: $0.name, ratingDouble: 5, isBinary: $0.isBinary)
      }
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
   
   func saveLog() {
      // Prevent duplicate saves
      guard !isSaving else { return }
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
         meals: settings.trackMeals ? logData.meals : [],
         activities: settings.trackActivities ? logData.activities : [],
         medicationsTaken: medicationsTaken,
         medicationAdherence: settings.trackMeds ? logData.medicationAdherence : [],
         notes: settings.trackNotes ? logData.notes : nil,
         isFlareDay: logData.isFlareDay,
         weather: settings.trackWeather ? logData.weather : nil,
         symptomRatings: logData.symptomRatings.map { $0.toModel() }
      )

      let result = logsRepository.saveLog(log)
      isSaving = false

      if result {
         let message = "Log saved successfully"
         toastManager.showToast(message: message, color: CloveColors.success, icon: Image(systemName: "checkmark.circle"))

         // Check for rating prompt opportunity
         Task {
            await AppReviewManager.shared.promptForReviewIfEligible()
         }
      } else {
         toastManager.showToast(message: "Hmm, something went wrong.", color: CloveColors.error)
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
