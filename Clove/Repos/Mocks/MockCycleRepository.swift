import Foundation

/// Mock implementation of CycleRepositoryProtocol for testing and previews
final class MockCycleRepository: CycleRepositoryProtocol {
    /// In-memory storage of cycle entries
    var cycles: [Cycle] = []

    /// Controls whether operations succeed or fail
    var shouldSucceed: Bool = true

    func save(_ cycles: [Cycle]) -> Bool {
        if shouldSucceed {
            self.cycles.append(contentsOf: cycles)
            return true
        }
        return false
    }

    func delete(id: Int64) -> Bool {
        if shouldSucceed {
            cycles.removeAll { $0.id == id }
            return true
        }
        return false
    }

    func getCyclesForDate(_ date: Date) -> [Cycle] {
        let calendar = Calendar.current
        return cycles.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func getAllCycles() -> [Cycle] {
        return cycles
    }

    func getCycles(for period: TimePeriod) -> [Cycle] {
        if period == .allTime {
            return cycles
        }

        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -period.days + 1, to: endDate) else {
            return []
        }

        return cycles.filter { $0.date >= startDate && $0.date <= endDate }
    }

    /// Convenience factory for creating a mock with sample data
    static func withSampleData(days: Int = 7) -> MockCycleRepository {
        let repo = MockCycleRepository()
        let calendar = Calendar.current

        let flowLevels: [FlowLevel] = [.spotting, .light, .medium, .heavy, .veryHeavy]

        for daysAgo in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) {
                let cycle = Cycle(
                    date: date,
                    flow: flowLevels.randomElement() ?? .medium,
                    isStartOfCycle: daysAgo % 28 == 0,
                    hasCramps: Bool.random()
                )
                repo.cycles.append(cycle)
            }
        }

        return repo
    }
}
