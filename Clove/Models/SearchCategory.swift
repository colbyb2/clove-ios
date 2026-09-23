import SwiftUI

enum SearchCategory: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case notes = "Notes"
    case symptoms = "Symptoms"
    case meals = "Meals"
    case activities = "Activities"
    case medications = "Medications"
    case bowelMovements = "Bowel Movements"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .notes:
            return "note.text"
        case .symptoms:
            return "bandage"
        case .meals:
            return "fork.knife"
        case .activities:
            return "figure.walk"
        case .medications:
            return "pills"
        case .bowelMovements:
            return "list.clipboard"
        }
    }

    var color: Color {
        switch self {
        case .notes:
            return CloveColors.blue
        case .symptoms:
            return CloveColors.red
        case .meals:
            return CloveColors.green
        case .activities:
            return CloveColors.orange
        case .medications:
            return CloveColors.accent
        case .bowelMovements:
            return Color.brown
        }
    }
}

enum SearchDateRange: String, CaseIterable, Codable, Identifiable, Sendable {
    case allTime
    case last7Days
    case last30Days
    case last90Days
    case thisMonth
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allTime: return "Any time"
        case .last7Days: return "Last 7 days"
        case .last30Days: return "Last 30 days"
        case .last90Days: return "Last 90 days"
        case .thisMonth: return "This month"
        case .custom: return "Custom range"
        }
    }
}

enum SearchSortOrder: String, CaseIterable, Codable, Identifiable, Sendable {
    case newestFirst
    case oldestFirst

    var id: String { rawValue }
    var title: String { self == .newestFirst ? "Newest first" : "Oldest first" }
}

/// A deterministic description of a search. Manual controls produce this today;
/// a future natural-language interpreter can produce the same value without
/// changing repository or result behavior.
struct SearchRequest: Equatable, Codable, Sendable {
    var query: String = ""
    var categories: Set<SearchCategory> = Set(SearchCategory.allCases)
    var dateRange: SearchDateRange = .allTime
    var customStartDate: Date?
    var customEndDate: Date?
    var sortOrder: SearchSortOrder = .newestFirst

    var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasRefinements: Bool {
        dateRange != .allTime || sortOrder != .newestFirst
    }

    func includes(_ date: Date, relativeTo referenceDate: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let interval = resolvedDateInterval(relativeTo: referenceDate, calendar: calendar) else {
            return true
        }
        // Search ranges are half-open so midnight after the selected final day
        // never leaks into the results.
        return date >= interval.start && date < interval.end
    }

    func resolvedDateInterval(relativeTo referenceDate: Date = Date(), calendar: Calendar = .current) -> DateInterval? {
        let today = calendar.startOfDay(for: referenceDate)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? referenceDate

        switch dateRange {
        case .allTime:
            return nil
        case .last7Days, .last30Days, .last90Days:
            let days = dateRange == .last7Days ? 7 : (dateRange == .last30Days ? 30 : 90)
            let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
            return DateInterval(start: start, end: tomorrow)
        case .thisMonth:
            guard let month = calendar.dateInterval(of: .month, for: referenceDate) else { return nil }
            return month
        case .custom:
            guard let customStartDate, let customEndDate else { return nil }
            let start = calendar.startOfDay(for: min(customStartDate, customEndDate))
            let inclusiveEnd = calendar.startOfDay(for: max(customStartDate, customEndDate))
            let end = calendar.date(byAdding: .day, value: 1, to: inclusiveEnd) ?? inclusiveEnd
            return DateInterval(start: start, end: end)
        }
    }
}

struct SearchCategoryFilters {
    var notes: Bool = true
    var symptoms: Bool = true
    var meals: Bool = true
    var activities: Bool = true
    var medications: Bool = true
    var bowelMovements: Bool = true

    init(categories: Set<SearchCategory> = Set(SearchCategory.allCases)) {
        notes = categories.contains(.notes)
        symptoms = categories.contains(.symptoms)
        meals = categories.contains(.meals)
        activities = categories.contains(.activities)
        medications = categories.contains(.medications)
        bowelMovements = categories.contains(.bowelMovements)
    }

    var categories: Set<SearchCategory> {
        Set(SearchCategory.allCases.filter(isActive))
    }

    func isActive(_ category: SearchCategory) -> Bool {
        switch category {
        case .notes:
            return notes
        case .symptoms:
            return symptoms
        case .meals:
            return meals
        case .activities:
            return activities
        case .medications:
            return medications
        case .bowelMovements:
            return bowelMovements
        }
    }

    mutating func toggle(_ category: SearchCategory) {
        switch category {
        case .notes:
            notes.toggle()
        case .symptoms:
            symptoms.toggle()
        case .meals:
            meals.toggle()
        case .activities:
            activities.toggle()
        case .medications:
            medications.toggle()
        case .bowelMovements:
            bowelMovements.toggle()
        }

        // Auto-enable Notes if all filters are disabled
        if !hasAnyFilterActive() {
            notes = true
        }
    }

    func hasAnyFilterActive() -> Bool {
        return notes || symptoms || meals || activities || medications || bowelMovements
    }
}
