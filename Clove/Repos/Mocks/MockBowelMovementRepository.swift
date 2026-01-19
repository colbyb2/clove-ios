import Foundation

/// Mock implementation of BowelMovementRepositoryProtocol for testing and previews
final class MockBowelMovementRepository: BowelMovementRepositoryProtocol {
    /// In-memory storage of bowel movements
    var movements: [BowelMovement] = []

    /// Controls whether operations succeed or fail
    var shouldSucceed: Bool = true

    func save(_ bowelMovements: [BowelMovement]) -> Bool {
        if shouldSucceed {
            movements.append(contentsOf: bowelMovements)
            return true
        }
        return false
    }

    func delete(id: Int64) -> Bool {
        if shouldSucceed {
            movements.removeAll { $0.id == id }
            return true
        }
        return false
    }

    func getBowelMovementsForDate(_ date: Date) -> [BowelMovement] {
        let calendar = Calendar.current
        return movements.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func getAllBowelMovements() -> [BowelMovement] {
        return movements
    }

    func getBowelMovements(for period: TimePeriod) -> [BowelMovement] {
        if period == .allTime {
            return movements
        }

        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -period.days + 1, to: endDate) else {
            return []
        }

        return movements.filter { $0.date >= startDate && $0.date <= endDate }
    }

    /// Convenience factory for creating a mock with sample data
    static func withSampleData(days: Int = 7) -> MockBowelMovementRepository {
        let repo = MockBowelMovementRepository()
        let calendar = Calendar.current

        for daysAgo in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) {
                let movement = BowelMovement(
                    type: Double.random(in: 1...7),
                    date: date,
                    notes: nil
                )
                repo.movements.append(movement)
            }
        }

        return repo
    }
}
