import Foundation
import GRDB

struct DailyLog: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var date: Date
    var mood: Int?
    var painLevel: Int?
    var energyLevel: Int?
    var meals: [String]
    var activities: [String]
    var medicationsTaken: [String]
    var notes: String?
    var isFlareDay: Bool
    var weather: String? // Weather description like "Sunny 72°F" or "Cloudy 45°F"

    // Store foreign key separately for linking
    var symptomRatingsJSON: String // JSON-encoded [SymptomRating]

    init(
        id: Int64? = nil,
        date: Date = Date(),
        mood: Int? = nil,
        painLevel: Int? = nil,
        energyLevel: Int? = nil,
        meals: [String] = [],
        activities: [String] = [],
        medicationsTaken: [String] = [],
        notes: String? = nil,
        isFlareDay: Bool = false,
        weather: String? = nil,
        symptomRatings: [SymptomRating] = []
    ) {
        self.id = id
        self.date = date
        self.mood = mood
        self.painLevel = painLevel
        self.energyLevel = energyLevel
        self.meals = meals
        self.activities = activities
        self.medicationsTaken = medicationsTaken
        self.notes = notes
        self.isFlareDay = isFlareDay
        self.weather = weather
        self.symptomRatingsJSON = try! JSONEncoder().encode(symptomRatings).toJSONString()
    }

    var symptomRatings: [SymptomRating] {
        (try? JSONDecoder().decode([SymptomRating].self, from: symptomRatingsJSON.data(using: .utf8)!)) ?? []
    }
}
