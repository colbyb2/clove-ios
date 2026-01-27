import Foundation
import GRDB

/// Categories for meal types
enum MealCategory: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack
    case beverage

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        case .beverage: return "Beverage"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "carrot.fill"
        case .beverage: return "cup.and.saucer.fill"
        }
    }

    var emoji: String {
        switch self {
        case .breakfast: return "🌅"
        case .lunch: return "☀️"
        case .dinner: return "🌙"
        case .snack: return "🍪"
        case .beverage: return "☕"
        }
    }
}

/// A food entry representing a single food/meal logged at a specific time
struct FoodEntry: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var name: String
    var category: MealCategory
    var date: Date
    var icon: String?
    var notes: String?
    var isFavorite: Bool

    init(
        id: Int64? = nil,
        name: String,
        category: MealCategory,
        date: Date = Date(),
        icon: String? = nil,
        notes: String? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.date = date
        self.icon = icon
        self.notes = notes
        self.isFavorite = isFavorite
    }

    // MARK: - GRDB Configuration

    static var databaseTableName: String { "foodEntry" }

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let category = Column(CodingKeys.category)
        static let date = Column(CodingKeys.date)
        static let icon = Column(CodingKeys.icon)
        static let notes = Column(CodingKeys.notes)
        static let isFavorite = Column(CodingKeys.isFavorite)
    }
}

// MARK: - Helper Extensions

extension FoodEntry {
    /// Returns the display text for the entry
    var displayText: String {
        if let icon = icon, !icon.isEmpty {
            return "\(icon) \(name)"
        }
        return name
    }

    /// Returns the time portion of the date formatted for display
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
