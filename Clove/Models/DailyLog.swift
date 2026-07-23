import Foundation
import GRDB

struct DailyLog: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var date: Date
    var mood: Int?
    var painLevel: Int?
    var energyLevel: Int?
    var waterIntake: Int?
    var meals: [String]
    var activities: [String]
    var medicationsTaken: [String]
    var medicationAdherenceJSON: String // JSON-encoded [MedicationAdherence]
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
        waterIntake: Int? = nil,
        meals: [String] = [],
        activities: [String] = [],
        medicationsTaken: [String] = [],
        medicationAdherence: [MedicationAdherence] = [],
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
        self.waterIntake = waterIntake
        self.meals = meals
        self.activities = activities
        self.medicationsTaken = medicationsTaken
        self.medicationAdherenceJSON = Self.encodeJSON(medicationAdherence)
        self.notes = notes
        self.isFlareDay = isFlareDay
        self.weather = weather
        self.symptomRatingsJSON = Self.encodeJSON(symptomRatings)
    }

    var symptomRatings: [SymptomRating] {
        Self.decodeJSON(symptomRatingsJSON, fallback: [])
    }
    
    var medicationAdherence: [MedicationAdherence] {
        Self.decodeJSON(medicationAdherenceJSON, fallback: [])
    }

    private static func encodeJSON<Value: Encodable>(_ value: Value) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private static func decodeJSON<Value: Decodable>(_ json: String, fallback: Value) -> Value {
        guard let data = json.data(using: .utf8),
              let value = try? JSONDecoder().decode(Value.self, from: data) else {
            return fallback
        }
        return value
    }
}
