import Foundation

enum TodayModule: String, CaseIterable, Codable, Identifiable {
    case mood
    case pain
    case energy
    case hydration
    case symptoms
    case meals
    case plans
    case activities
    case medications
    case weather
    case bowelMovements
    case cycle
    case notes
    case flare

    // `plans` remains decodable so existing saved layouts migrate cleanly, but
    // Gentle Plans now has its own Today surface instead of being a module.
    static let allCases: [TodayModule] = [
        .mood, .pain, .energy, .hydration, .symptoms, .meals, .activities,
        .medications, .weather, .bowelMovements, .cycle, .notes, .flare
    ]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mood: "Mood"
        case .pain: "Pain"
        case .energy: "Energy"
        case .hydration: "Hydration"
        case .symptoms: "Symptoms"
        case .meals: "Meals"
        case .plans: "Gentle Plans"
        case .activities: "Activities"
        case .medications: "Medications"
        case .weather: "Weather"
        case .bowelMovements: "Bowel Movements"
        case .cycle: "Cycle"
        case .notes: "Notes"
        case .flare: "Flare Day"
        }
    }

    var icon: String {
        switch self {
        case .mood: "face.smiling"
        case .pain: "bandage.fill"
        case .energy: "bolt.fill"
        case .hydration: "drop.fill"
        case .symptoms: "stethoscope"
        case .meals: "fork.knife"
        case .plans: "leaf.fill"
        case .activities: "figure.run"
        case .medications: "pills.fill"
        case .weather: "cloud.sun.fill"
        case .bowelMovements: "toilet.fill"
        case .cycle: "calendar.circle.fill"
        case .notes: "note.text"
        case .flare: "exclamationmark.triangle.fill"
        }
    }
}

struct TodayLayoutPreferences: Codable, Equatable {
    static let storageKey = "todayLayoutPreferences"

    var order: [TodayModule]
    var hidden: Set<TodayModule>
    var collapsed: Set<TodayModule>
    var essentials: Set<TodayModule>

    static var `default`: TodayLayoutPreferences {
        TodayLayoutPreferences(
            order: TodayModule.allCases,
            hidden: [],
            collapsed: [],
            essentials: [.mood, .pain, .energy, .symptoms, .medications]
        )
    }

    static func load(defaults: UserDefaults = .standard) -> TodayLayoutPreferences {
        guard let data = defaults.data(forKey: storageKey),
              var value = try? JSONDecoder().decode(TodayLayoutPreferences.self, from: data) else {
            var value = TodayLayoutPreferences.default
            if defaults.object(forKey: Constants.SHOW_CYCLE_ON_TODAY) != nil,
               !defaults.bool(forKey: Constants.SHOW_CYCLE_ON_TODAY) {
                value.hidden.insert(.cycle)
            }
            value.save(defaults: defaults)
            return value
        }
        value.normalize()
        return value
    }

    func save(defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    mutating func normalize() {
        let known = Set(TodayModule.allCases)
        var seen: Set<TodayModule> = []
        order = order.filter { known.contains($0) && seen.insert($0).inserted }
        order.append(contentsOf: TodayModule.allCases.filter { !seen.contains($0) })
        hidden.formIntersection(known)
        collapsed.formIntersection(known)
        essentials.formIntersection(known)
    }
}
