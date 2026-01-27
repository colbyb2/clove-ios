import Foundation

/// Mock implementation of FoodEntryRepositoryProtocol for testing and previews
final class MockFoodEntryRepository: FoodEntryRepositoryProtocol {
    /// In-memory storage of food entries
    var entries: [FoodEntry] = []

    /// Counter for generating unique IDs
    private var nextId: Int64 = 1

    /// Controls whether operations succeed or fail
    var shouldSucceed: Bool = true

    @discardableResult
    func save(_ entry: FoodEntry) -> FoodEntry? {
        if shouldSucceed {
            var newEntry = entry
            newEntry.id = nextId
            nextId += 1
            entries.append(newEntry)
            return newEntry
        }
        return nil
    }

    func save(_ newEntries: [FoodEntry]) -> Bool {
        if shouldSucceed {
            for entry in newEntries {
                var newEntry = entry
                newEntry.id = nextId
                nextId += 1
                entries.append(newEntry)
            }
            return true
        }
        return false
    }

    func update(_ entry: FoodEntry) -> Bool {
        guard shouldSucceed, let id = entry.id else { return false }
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index] = entry
            return true
        }
        return false
    }

    func delete(id: Int64) -> Bool {
        if shouldSucceed {
            entries.removeAll { $0.id == id }
            return true
        }
        return false
    }

    func getEntriesForDate(_ date: Date) -> [FoodEntry] {
        let calendar = Calendar.current
        return entries.filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }

    func getAllEntries() -> [FoodEntry] {
        return entries.sorted { $0.date > $1.date }
    }

    func getEntries(for period: TimePeriod) -> [FoodEntry] {
        if period == .allTime {
            return getAllEntries()
        }

        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -period.days + 1, to: endDate) else {
            return []
        }

        return entries.filter { $0.date >= startDate && $0.date <= Date() }
            .sorted { $0.date > $1.date }
    }

    func getFavorites() -> [FoodEntry] {
        return entries.filter { $0.isFavorite }.sorted { $0.name < $1.name }
    }

    func getRecentFoodNames(limit: Int) -> [String] {
        let sortedEntries = entries.sorted { $0.date > $1.date }
        var uniqueNames: [String] = []
        for entry in sortedEntries {
            if !uniqueNames.contains(entry.name) {
                uniqueNames.append(entry.name)
                if uniqueNames.count >= limit { break }
            }
        }
        return uniqueNames
    }

    func getEntriesGroupedByCategory(for date: Date) -> [MealCategory: [FoodEntry]] {
        let dateEntries = getEntriesForDate(date)
        return Dictionary(grouping: dateEntries, by: { $0.category })
    }

    func toggleFavorite(id: Int64) -> Bool {
        guard shouldSucceed else { return false }
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].isFavorite.toggle()
            return true
        }
        return false
    }

    func search(query: String) -> [FoodEntry] {
        guard !query.isEmpty else { return [] }
        return entries.filter { $0.name.lowercased().contains(query.lowercased()) }
            .sorted { $0.date > $1.date }
    }

    /// Convenience factory for creating a mock with sample data
    static func withSampleData(days: Int = 7) -> MockFoodEntryRepository {
        let repo = MockFoodEntryRepository()
        let calendar = Calendar.current

        let sampleFoods: [(String, MealCategory)] = [
            ("Oatmeal", .breakfast),
            ("Coffee", .beverage),
            ("Sandwich", .lunch),
            ("Apple", .snack),
            ("Grilled Chicken", .dinner),
            ("Tea", .beverage),
            ("Yogurt", .breakfast),
            ("Salad", .lunch)
        ]

        for daysAgo in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) {
                // Add 2-4 random food entries per day
                let count = Int.random(in: 2...4)
                for i in 0..<count {
                    let (name, category) = sampleFoods[i % sampleFoods.count]
                    let entry = FoodEntry(
                        name: name,
                        category: category,
                        date: date,
                        isFavorite: Bool.random()
                    )
                    _ = repo.save(entry)
                }
            }
        }

        return repo
    }
}
