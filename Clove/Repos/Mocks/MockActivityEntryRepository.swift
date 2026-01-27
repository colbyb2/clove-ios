import Foundation

/// Mock implementation of ActivityEntryRepositoryProtocol for testing and previews
final class MockActivityEntryRepository: ActivityEntryRepositoryProtocol {
    /// In-memory storage of activity entries
    var entries: [ActivityEntry] = []

    /// Counter for generating unique IDs
    private var nextId: Int64 = 1

    /// Controls whether operations succeed or fail
    var shouldSucceed: Bool = true

    @discardableResult
    func save(_ entry: ActivityEntry) -> ActivityEntry? {
        if shouldSucceed {
            var newEntry = entry
            newEntry.id = nextId
            nextId += 1
            entries.append(newEntry)
            return newEntry
        }
        return nil
    }

    func save(_ newEntries: [ActivityEntry]) -> Bool {
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

    func update(_ entry: ActivityEntry) -> Bool {
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

    func getEntriesForDate(_ date: Date) -> [ActivityEntry] {
        let calendar = Calendar.current
        return entries.filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }

    func getAllEntries() -> [ActivityEntry] {
        return entries.sorted { $0.date > $1.date }
    }

    func getEntries(for period: TimePeriod) -> [ActivityEntry] {
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

    func getFavorites() -> [ActivityEntry] {
        return entries.filter { $0.isFavorite }.sorted { $0.name < $1.name }
    }

    func getRecentActivityNames(limit: Int) -> [String] {
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

    func getEntriesGroupedByCategory(for date: Date) -> [ActivityCategory: [ActivityEntry]] {
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

    func search(query: String) -> [ActivityEntry] {
        guard !query.isEmpty else { return [] }
        return entries.filter { $0.name.lowercased().contains(query.lowercased()) }
            .sorted { $0.date > $1.date }
    }

    func getTotalDuration(for date: Date) -> Int {
        let dateEntries = getEntriesForDate(date)
        return dateEntries.compactMap { $0.duration }.reduce(0, +)
    }

    /// Convenience factory for creating a mock with sample data
    static func withSampleData(days: Int = 7) -> MockActivityEntryRepository {
        let repo = MockActivityEntryRepository()
        let calendar = Calendar.current

        let sampleActivities: [(String, ActivityCategory, Int?, ActivityIntensity?)] = [
            ("Morning Run", .exercise, 30, .medium),
            ("Yoga", .wellness, 20, .low),
            ("Walking", .exercise, 45, .low),
            ("Gym Workout", .exercise, 60, .high),
            ("Meditation", .wellness, 15, .low),
            ("Cleaning", .chores, 30, nil),
            ("Reading", .rest, 45, nil),
            ("Lunch with Friends", .social, 90, nil)
        ]

        for daysAgo in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) {
                // Add 1-3 random activity entries per day
                let count = Int.random(in: 1...3)
                for i in 0..<count {
                    let (name, category, duration, intensity) = sampleActivities[i % sampleActivities.count]
                    let entry = ActivityEntry(
                        name: name,
                        category: category,
                        date: date,
                        duration: duration,
                        intensity: intensity,
                        isFavorite: Bool.random()
                    )
                    _ = repo.save(entry)
                }
            }
        }

        return repo
    }
}
