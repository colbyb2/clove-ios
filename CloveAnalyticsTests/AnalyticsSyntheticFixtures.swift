import Foundation
@testable import Clove

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}

enum AnalyticsSyntheticFixtures {
    static func increasing(count: Int) -> [Double] {
        (0..<count).map(Double.init)
    }

    static func decreasing(count: Int) -> [Double] {
        Array(increasing(count: count).reversed())
    }

    static func constant(value: Double, count: Int) -> [Double] {
        Array(repeating: value, count: count)
    }

    static func seededNoise(seed: UInt64, count: Int) -> [Double] {
        var generator = SeededGenerator(seed: seed)
        return (0..<count).map { _ in Double.random(in: -1...1, using: &generator) }
    }

    static func sparseDates() -> [Date] {
        [1, 3, 8, 21].map { AnalyticsTestDates.date($0) }
    }

    static let binaryEvents = [true, false, true, true, false]
    static let ordinalValues = [1.0, 2.0, 2.0, 4.0, 5.0]
    static let categoricalValues = ["Sunny", "Rainy", "Sunny", "Cloudy"]
    static let duplicateCounts = [1.0, 1.0, 1.0]
}
