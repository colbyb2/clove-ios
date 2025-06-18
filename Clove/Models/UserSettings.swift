import GRDB

struct UserSettings: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64? = 1 // always ID 1 (singleton row)

    var trackMood: Bool
    var trackPain: Bool
    var trackEnergy: Bool
    var trackSymptoms: Bool
    var trackMeals: Bool
    var trackActivities: Bool
    var trackMeds: Bool
    var showFlareToggle: Bool
}

extension UserSettings {
    /// Default settings configuration
    static let `default` = UserSettings(
        trackMood: true,
        trackPain: false,
        trackEnergy: true,
        trackSymptoms: true,
        trackMeals: false,
        trackActivities: false,
        trackMeds: false,
        showFlareToggle: true
    )
}
