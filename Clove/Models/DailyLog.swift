import Foundation
import GRDB

struct DailyLog: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var date: Date
    var dayKey: String
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
        dayKey: String? = nil,
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
        self.dayKey = dayKey ?? LocalDayKey.make(for: date)
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

    private enum CodingKeys: String, CodingKey {
        case id, date, dayKey, mood, painLevel, energyLevel, waterIntake
        case meals, activities, medicationsTaken, medicationAdherenceJSON
        case notes, isFlareDay, weather, symptomRatingsJSON
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int64.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        dayKey = try container.decodeIfPresent(String.self, forKey: .dayKey)
            ?? LocalDayKey.make(for: date)
        mood = try container.decodeIfPresent(Int.self, forKey: .mood)
        painLevel = try container.decodeIfPresent(Int.self, forKey: .painLevel)
        energyLevel = try container.decodeIfPresent(Int.self, forKey: .energyLevel)
        waterIntake = try container.decodeIfPresent(Int.self, forKey: .waterIntake)
        meals = try container.decodeIfPresent([String].self, forKey: .meals) ?? []
        activities = try container.decodeIfPresent([String].self, forKey: .activities) ?? []
        medicationsTaken = try container.decodeIfPresent([String].self, forKey: .medicationsTaken) ?? []
        medicationAdherenceJSON = try container.decodeIfPresent(String.self, forKey: .medicationAdherenceJSON) ?? "[]"
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isFlareDay = try container.decodeIfPresent(Bool.self, forKey: .isFlareDay) ?? false
        weather = try container.decodeIfPresent(String.self, forKey: .weather)
        symptomRatingsJSON = try container.decodeIfPresent(String.self, forKey: .symptomRatingsJSON) ?? "[]"
    }

    func date(in calendar: Calendar) -> Date {
        LocalDayKey.date(from: dayKey, calendar: calendar) ?? date
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

enum LocalDayKey {
    static func make(for date: Date, calendar: Calendar = .current) -> String {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let components = gregorian.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func date(from key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        return gregorian.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
