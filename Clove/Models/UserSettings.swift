import GRDB
import Foundation

struct UserSettings: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64? = 1 // always ID 1 (singleton row)

    var trackMood: Bool
    var trackPain: Bool
    var trackEnergy: Bool
    var trackHydration: Bool
    var autoSaveEnabled: Bool
    var trackSymptoms: Bool
    var trackMeals: Bool
    var trackActivities: Bool
    var trackMeds: Bool
    var showFlareToggle: Bool
    var trackWeather: Bool
    var trackNotes: Bool
    var trackBowelMovements: Bool
    var trackCycle: Bool
    var trackCustomMetrics: Bool = false
    var trackSleep: Bool = false
}

extension UserSettings {
    /// Default settings configuration
    static let `default` = UserSettings(
        trackMood: true,
        trackPain: false,
        trackEnergy: true,
        trackHydration: false,
        autoSaveEnabled: true,
        trackSymptoms: true,
        trackMeals: false,
        trackActivities: false,
        trackMeds: false,
        showFlareToggle: true,
        trackWeather: true,
        trackNotes: true,
        trackBowelMovements: false,
        trackCycle: false
    )

    /// Blank settings
    static let blank = UserSettings(
        trackMood: false,
        trackPain: false,
        trackEnergy: false,
        trackHydration: false,
        autoSaveEnabled: true,
        trackSymptoms: false,
        trackMeals: false,
        trackActivities: false,
        trackMeds: false,
        showFlareToggle: false,
        trackWeather: false,
        trackNotes: false,
        trackBowelMovements: false,
        trackCycle: false
    )
}

extension UserSettings {
    func isSomeEnabled() -> Bool {
        return trackMood || trackPain || trackEnergy || trackHydration || trackSymptoms || trackMeals || trackActivities || trackMeds || showFlareToggle || trackWeather || trackNotes || trackBowelMovements || trackCycle || trackCustomMetrics || trackSleep
    }
}

extension UserSettings {
    private enum CodingKeys: String, CodingKey {
        case id, trackMood, trackPain, trackEnergy, trackHydration, autoSaveEnabled, trackSymptoms, trackMeals, trackActivities, trackMeds, showFlareToggle, trackWeather, trackNotes, trackBowelMovements, trackCycle, trackCustomMetrics, trackSleep
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int64.self, forKey: .id)
        trackMood = try c.decode(Bool.self, forKey: .trackMood)
        trackPain = try c.decode(Bool.self, forKey: .trackPain)
        trackEnergy = try c.decode(Bool.self, forKey: .trackEnergy)
        trackHydration = try c.decode(Bool.self, forKey: .trackHydration)
        autoSaveEnabled = try c.decode(Bool.self, forKey: .autoSaveEnabled)
        trackSymptoms = try c.decode(Bool.self, forKey: .trackSymptoms)
        trackMeals = try c.decode(Bool.self, forKey: .trackMeals)
        trackActivities = try c.decode(Bool.self, forKey: .trackActivities)
        trackMeds = try c.decode(Bool.self, forKey: .trackMeds)
        showFlareToggle = try c.decode(Bool.self, forKey: .showFlareToggle)
        trackWeather = try c.decode(Bool.self, forKey: .trackWeather)
        trackNotes = try c.decode(Bool.self, forKey: .trackNotes)
        trackBowelMovements = try c.decode(Bool.self, forKey: .trackBowelMovements)
        trackCycle = try c.decode(Bool.self, forKey: .trackCycle)
        trackSleep = try c.decodeIfPresent(Bool.self, forKey: .trackSleep) ?? false
        trackCustomMetrics = try c.decodeIfPresent(Bool.self, forKey: .trackCustomMetrics) ?? false
    }
    func encode(to container: inout PersistenceContainer) throws {
        container["id"] = id
        container["trackMood"] = trackMood
        container["trackPain"] = trackPain
        container["trackEnergy"] = trackEnergy
        container["trackHydration"] = trackHydration
        container["autoSaveEnabled"] = autoSaveEnabled
        container["trackSymptoms"] = trackSymptoms
        container["trackMeals"] = trackMeals
        container["trackActivities"] = trackActivities
        container["trackMeds"] = trackMeds
        container["showFlareToggle"] = showFlareToggle
        container["trackWeather"] = trackWeather
        container["trackNotes"] = trackNotes
        container["trackBowelMovements"] = trackBowelMovements
        container["trackCycle"] = trackCycle
        container["trackCustomMetrics"] = trackCustomMetrics
        container["trackSleep"] = trackSleep
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(id, forKey: .id)
        try c.encode(trackMood, forKey: .trackMood)
        try c.encode(trackPain, forKey: .trackPain)
        try c.encode(trackEnergy, forKey: .trackEnergy)
        try c.encode(trackHydration, forKey: .trackHydration)
        try c.encode(autoSaveEnabled, forKey: .autoSaveEnabled)
        try c.encode(trackSymptoms, forKey: .trackSymptoms)
        try c.encode(trackMeals, forKey: .trackMeals)
        try c.encode(trackActivities, forKey: .trackActivities)
        try c.encode(trackMeds, forKey: .trackMeds)
        try c.encode(showFlareToggle, forKey: .showFlareToggle)
        try c.encode(trackWeather, forKey: .trackWeather)
        try c.encode(trackNotes, forKey: .trackNotes)
        try c.encode(trackBowelMovements, forKey: .trackBowelMovements)
        try c.encode(trackCycle, forKey: .trackCycle)
        if trackSleep { try c.encode(true, forKey: .trackSleep) }
        if trackCustomMetrics { try c.encode(true, forKey: .trackCustomMetrics) }
    }
}
