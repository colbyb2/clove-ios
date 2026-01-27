import Foundation
import GRDB

/// Categories for activity types
enum ActivityCategory: String, Codable, CaseIterable, Identifiable {
    case exercise
    case wellness
    case social
    case chores
    case rest
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .exercise: return "Exercise"
        case .wellness: return "Wellness"
        case .social: return "Social"
        case .chores: return "Chores"
        case .rest: return "Rest"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .exercise: return "figure.run"
        case .wellness: return "heart.fill"
        case .social: return "person.2.fill"
        case .chores: return "house.fill"
        case .rest: return "bed.double.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var emoji: String {
        switch self {
        case .exercise: return "🏃"
        case .wellness: return "🧘"
        case .social: return "👥"
        case .chores: return "🏠"
        case .rest: return "😴"
        case .other: return "✨"
        }
    }
}

/// Intensity levels for activities
enum ActivityIntensity: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    /// Returns filled circles representing intensity (e.g., "●○○" for low)
    var indicator: String {
        switch self {
        case .low: return "●○○"
        case .medium: return "●●○"
        case .high: return "●●●"
        }
    }

    var intValue: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }
}

/// An activity entry representing a single activity logged at a specific time
struct ActivityEntry: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var name: String
    var category: ActivityCategory
    var date: Date
    var duration: Int?  // Duration in minutes
    var intensity: ActivityIntensity?
    var icon: String?
    var notes: String?
    var isFavorite: Bool

    init(
        id: Int64? = nil,
        name: String,
        category: ActivityCategory,
        date: Date = Date(),
        duration: Int? = nil,
        intensity: ActivityIntensity? = nil,
        icon: String? = nil,
        notes: String? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.date = date
        self.duration = duration
        self.intensity = intensity
        self.icon = icon
        self.notes = notes
        self.isFavorite = isFavorite
    }

    // MARK: - GRDB Configuration

    static var databaseTableName: String { "activityEntry" }

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let category = Column(CodingKeys.category)
        static let date = Column(CodingKeys.date)
        static let duration = Column(CodingKeys.duration)
        static let intensity = Column(CodingKeys.intensity)
        static let icon = Column(CodingKeys.icon)
        static let notes = Column(CodingKeys.notes)
        static let isFavorite = Column(CodingKeys.isFavorite)
    }
}

// MARK: - Helper Extensions

extension ActivityEntry {
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

    /// Returns a formatted duration string (e.g., "30 min", "1h 15m")
    var formattedDuration: String? {
        guard let duration = duration else { return nil }

        if duration < 60 {
            return "\(duration) min"
        } else {
            let hours = duration / 60
            let minutes = duration % 60
            if minutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(minutes)m"
            }
        }
    }
}
