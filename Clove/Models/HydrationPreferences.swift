import Foundation

enum HydrationUnit: String, CaseIterable, Identifiable {
    case fluidOunces
    case milliliters

    var id: String { rawValue }
    var title: String { self == .fluidOunces ? "Fluid ounces" : "Milliliters" }
    var symbol: String { self == .fluidOunces ? "fl oz" : "mL" }
    var adjustmentStep: Int { self == .fluidOunces ? 1 : 50 }

    func displayValue(fromCanonicalOunces ounces: Int) -> Int {
        switch self {
        case .fluidOunces: ounces
        case .milliliters: Int((Double(ounces) * 29.5735).rounded())
        }
    }

    func canonicalOunces(fromDisplayValue value: Int) -> Int {
        switch self {
        case .fluidOunces: value
        case .milliliters: Int((Double(value) / 29.5735).rounded())
        }
    }

    func formatted(canonicalOunces: Int) -> String {
        "\(displayValue(fromCanonicalOunces: canonicalOunces)) \(symbol)"
    }
}

enum HydrationPreferences {
    static func unit(defaults: UserDefaults = .standard) -> HydrationUnit {
        HydrationUnit(rawValue: defaults.string(forKey: Constants.HYDRATION_UNIT) ?? "") ?? .fluidOunces
    }

    static func quickAmounts(for unit: HydrationUnit, defaults: UserDefaults = .standard) -> [Int] {
        let key = unit == .fluidOunces
            ? Constants.HYDRATION_QUICK_AMOUNTS_OUNCES
            : Constants.HYDRATION_QUICK_AMOUNTS_MILLILITERS
        let fallback = unit == .fluidOunces ? [8, 12, 16] : [250, 350, 500]
        guard let values = defaults.array(forKey: key) as? [Int], values.count == 3 else { return fallback }
        return values
    }

    static func saveQuickAmounts(_ values: [Int], for unit: HydrationUnit, defaults: UserDefaults = .standard) {
        let key = unit == .fluidOunces
            ? Constants.HYDRATION_QUICK_AMOUNTS_OUNCES
            : Constants.HYDRATION_QUICK_AMOUNTS_MILLILITERS
        defaults.set(Array(values.prefix(3)), forKey: key)
    }

    static func goalIsEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: Constants.HYDRATION_GOAL_ENABLED) as? Bool ?? true
    }
}
