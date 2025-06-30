import Foundation

@Observable
class SuggestionRepository {
    static let shared = SuggestionRepository()
    
    private let mealsKey = "meals_suggestions"
    private let activitiesKey = "activities_suggestions"
    private let maxSuggestions = 50
    
    private init() {}
    
    // MARK: - Public Methods
    
    func getSuggestions(for type: SuggestionType) -> [String] {
        let key = type == .meals ? mealsKey : activitiesKey
        let suggestions = UserDefaults.standard.stringArray(forKey: key) ?? getDefaultSuggestions(for: type)
        return Array(suggestions.prefix(maxSuggestions))
    }
    
    func addSuggestion(_ item: String, for type: SuggestionType) {
        let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        var suggestions = getSuggestions(for: type)
        
        // Remove if already exists (case-insensitive)
        suggestions.removeAll { $0.lowercased() == trimmed.lowercased() }
        
        // Add to front (most recent first)
        suggestions.insert(trimmed, at: 0)
        
        // Keep only max suggestions
        suggestions = Array(suggestions.prefix(maxSuggestions))
        
        let key = type == .meals ? mealsKey : activitiesKey
        UserDefaults.standard.set(suggestions, forKey: key)
    }
    
    func getFilteredSuggestions(for type: SuggestionType, query: String) -> [String] {
        guard !query.isEmpty else { return Array(getSuggestions(for: type).prefix(8)) }
        
        let suggestions = getSuggestions(for: type)
        let filtered = suggestions.filter { suggestion in
            suggestion.lowercased().contains(query.lowercased())
        }
        
        // Sort by relevance: exact matches first, then starts with, then contains
        let sorted = filtered.sorted { first, second in
            let query = query.lowercased()
            let firstLower = first.lowercased()
            let secondLower = second.lowercased()
            
            if firstLower == query && secondLower != query { return true }
            if firstLower != query && secondLower == query { return false }
            if firstLower.hasPrefix(query) && !secondLower.hasPrefix(query) { return true }
            if !firstLower.hasPrefix(query) && secondLower.hasPrefix(query) { return false }
            
            return first.count < second.count // Prefer shorter matches
        }
        
        return Array(sorted.prefix(8))
    }
    
    // MARK: - Private Methods
    
    private func getDefaultSuggestions(for type: SuggestionType) -> [String] {
        switch type {
        case .meals:
            return [
                "Breakfast", "Lunch", "Dinner", "Snack",
                "Sandwich", "Salad", "Pizza", "Pasta",
                "Chicken", "Fish", "Soup", "Smoothie",
                "Coffee", "Tea", "Water", "Fruit"
            ]
        case .activities:
            return [
                "Walking", "Running", "Swimming", "Cycling",
                "Yoga", "Gym", "Stretching", "Dancing",
                "Reading", "Work", "Cooking", "Shopping",
                "Meditation", "Rest", "Cleaning", "Driving"
            ]
        }
    }
}

enum SuggestionType {
    case meals
    case activities
}