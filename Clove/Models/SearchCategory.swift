import SwiftUI

enum SearchCategory: String, CaseIterable, Identifiable {
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

struct SearchCategoryFilters {
    var notes: Bool = true
    var symptoms: Bool = false
    var meals: Bool = false
    var activities: Bool = false
    var medications: Bool = false
    var bowelMovements: Bool = false

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
            return activities.toggle()
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
