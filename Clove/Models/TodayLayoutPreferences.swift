import Foundation

enum TodayModule: String, CaseIterable, Codable, Identifiable {
    case mood
    case pain
    case energy
    case hydration
    case sleep
    case symptoms
    case customMetrics
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
        .mood, .pain, .energy, .hydration, .sleep, .symptoms, .meals, .activities,
        .medications, .weather, .bowelMovements, .cycle, .notes, .flare, .customMetrics
    ]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mood: "Mood"
        case .pain: "Pain"
        case .energy: "Energy"
        case .hydration: "Hydration"
        case .sleep: "Sleep"
        case .customMetrics: "Custom Tracking"
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
        case .sleep: "bed.double.fill"
        case .customMetrics: "slider.horizontal.3"
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

/// A stable layout identity, independent of a custom metric's editable name.
enum TodayLayoutItem: Hashable, Identifiable {
    case module(TodayModule)
    case customMetric(String)

    var id: String {
        switch self {
        case .module(let module): module.rawValue
        case .customMetric(let id): "custom:\(id)"
        }
    }

    init?(id: String) {
        if id.hasPrefix("custom:"), id.count > "custom:".count {
            self = .customMetric(String(id.dropFirst("custom:".count)))
        } else if let module = TodayModule(rawValue: id), module != .customMetrics, module != .plans {
            self = .module(module)
        } else {
            return nil
        }
    }
}

struct TodayItemLayout: Codable, Equatable {
    var order: [String]
    var hiddenCustomMetrics: Set<String>
    var essentialCustomMetrics: Set<String>
}

struct TodayLayoutPreferences: Codable, Equatable {
    static let storageKey = "todayLayoutPreferences"

    var order: [TodayModule]
    var hidden: Set<TodayModule>
    var collapsed: Set<TodayModule>
    var essentials: Set<TodayModule>
    // Optional so layouts saved before individual custom metrics still decode.
    var itemLayout: TodayItemLayout? = nil

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

    /// Expand the legacy group at its saved position. Keep temporarily disabled or
    /// archived metric IDs in the saved order so restoring them restores placement.
    func items(customMetricIDs: [String]) -> [TodayLayoutItem] {
        let legacyItems = order.flatMap { module -> [TodayLayoutItem] in
            if module == .customMetrics { return customMetricIDs.map(TodayLayoutItem.customMetric) }
            return module == .plans ? [] : [.module(module)]
        }
        let savedItems = itemLayout?.order.compactMap { TodayLayoutItem(id: $0) } ?? legacyItems
        var seen: Set<TodayLayoutItem> = []
        return (savedItems + legacyItems + customMetricIDs.map(TodayLayoutItem.customMetric))
            .filter { seen.insert($0).inserted }
    }

    func isHidden(_ item: TodayLayoutItem) -> Bool {
        switch item {
        case .module(let module): hidden.contains(module)
        case .customMetric(let id): itemLayout?.hiddenCustomMetrics.contains(id) ?? hidden.contains(.customMetrics)
        }
    }

    func isEssential(_ item: TodayLayoutItem) -> Bool {
        switch item {
        case .module(let module): essentials.contains(module)
        case .customMetric(let id): itemLayout?.essentialCustomMetrics.contains(id) ?? essentials.contains(.customMetrics)
        }
    }

    mutating func setItems(_ items: [TodayLayoutItem]) {
        let hiddenIDs = items.compactMap { item -> String? in
            guard case .customMetric(let id) = item, isHidden(item) else { return nil }
            return id
        }
        let essentialIDs = items.compactMap { item -> String? in
            guard case .customMetric(let id) = item, isEssential(item) else { return nil }
            return id
        }
        itemLayout = TodayItemLayout(
            order: items.map(\.id),
            hiddenCustomMetrics: Set(hiddenIDs),
            essentialCustomMetrics: Set(essentialIDs)
        )
        // Keep the built-in representation current for existing preference controls.
        order = items.compactMap { if case .module(let module) = $0 { return module }; return nil }
        normalize()
    }

    mutating func setHidden(_ hidden: Bool, for item: TodayLayoutItem) {
        switch item {
        case .module(let module):
            if hidden { self.hidden.insert(module) } else { self.hidden.remove(module) }
        case .customMetric(let id):
            if hidden { itemLayout?.hiddenCustomMetrics.insert(id) } else { itemLayout?.hiddenCustomMetrics.remove(id) }
        }
    }

    mutating func setEssential(_ essential: Bool, for item: TodayLayoutItem) {
        switch item {
        case .module(let module):
            if essential { essentials.insert(module) } else { essentials.remove(module) }
        case .customMetric(let id):
            if essential { itemLayout?.essentialCustomMetrics.insert(id) } else { itemLayout?.essentialCustomMetrics.remove(id) }
        }
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
