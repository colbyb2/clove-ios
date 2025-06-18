import SwiftUI
import Foundation
import GRDB

@Observable
class TodayViewModel {
    var settings: UserSettings = .default
    var mood: Int = 3
    var painLevel: Double = 5
    var energyLevel: Double = 5
    var isFlareDay: Bool = false
    var symptomRatings: [SymptomRatingVM] = []

    func load() {
        loadSettings()
        loadTrackedSymptoms()
    }

    func loadSettings() {
        self.settings = UserSettingsRepo.shared.getSettings() ?? .default
    }

    func loadTrackedSymptoms() {
        let trackedSymptoms = SymptomsRepo.shared.getTrackedSymptoms()
        self.symptomRatings = trackedSymptoms.map { SymptomRatingVM(symptomName: $0.name, order: $0.order, ratingDouble: 5) }
    }

    func saveLog() {
        let log = DailyLog(
            date: Date(),
            mood: settings.trackMood ? mood : nil,
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
