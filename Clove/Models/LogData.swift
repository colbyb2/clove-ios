import SwiftUI

/// Observable data container for daily log entry form state.
/// This is a pure data container with no database dependencies - all data loading
/// should be performed by the ViewModel and passed in via initializers.
@Observable
class LogData {
    /// Nil means the user has not answered this input for the selected day.
    /// Zero remains a valid, explicitly selected answer.
    var mood: Double? = nil
    var painLevel: Double? = nil
    var energyLevel: Double? = nil
    var waterIntake: Int = 0
    var isFlareDay: Bool = false
    var weather: String? = nil
    var meals: [String] = []
    var activities: [String] = []
    var medicationAdherence: [MedicationAdherence] = []
    var notes: String? = nil
    var bowelMovements: [BowelMovement] = []
    var symptomRatings: [SymptomRatingVM] = []

    /// Computed property to get medications that were taken
    var medicationsTaken: [String] {
        return medicationAdherence
            .filter { $0.wasTaken }
            .map { $0.medicationName }
    }

    /// Creates a new empty LogData with default values
    init() {
        // Pure initialization - no side effects or database calls
    }

    /// Creates LogData from an existing DailyLog, optionally with bowel movements
    /// - Parameters:
    ///   - log: The DailyLog to populate from
    ///   - bowelMovements: Bowel movements for this date (loaded externally by ViewModel)
    init(from log: DailyLog, bowelMovements: [BowelMovement] = []) {
        self.mood = log.mood.map(Double.init)
        self.painLevel = log.painLevel.map(Double.init)
        self.energyLevel = log.energyLevel.map(Double.init)
        self.waterIntake = log.waterIntake ?? 0
        self.isFlareDay = log.isFlareDay
        self.weather = log.weather
        self.meals = log.meals
        self.activities = log.activities
        self.medicationAdherence = log.medicationAdherence
        self.notes = log.notes
        self.symptomRatings = log.symptomRatings.map { s in
            SymptomRatingVM(symptomId: s.symptomId, symptomName: s.symptomName, ratingDouble: Double(s.rating), isBinary: s.isBinary)
        }
        self.bowelMovements = bowelMovements
    }
}
