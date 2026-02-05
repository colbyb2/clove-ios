//
//  CycleManager.swift
//  Clove
//
//  Created by Colby Brown on 2/4/26.
//

import SwiftUI

enum CycleRegularity {
    case regular
    case somewhatRegular
    case irregular
    case insufficientData

    var displayName: String {
        switch self {
        case .regular: return "Regular"
        case .somewhatRegular: return "Somewhat Regular"
        case .irregular: return "Irregular"
        case .insufficientData: return "Insufficient Data"
        }
    }

    var description: String {
        switch self {
        case .regular: return "Cycle length varies by ±3 days"
        case .somewhatRegular: return "Cycle length varies by ±6 days"
        case .irregular: return "Cycle length varies by >6 days"
        case .insufficientData: return "Track more cycles for analysis"
        }
    }

    var color: Color {
        switch self {
        case .regular: return .green
        case .somewhatRegular: return .orange
        case .irregular: return .red
        case .insufficientData: return .gray
        }
    }
}

protocol CycleManaging {
    func getNextCycle() -> CyclePrediction?
    func getAverageCycleLength() -> Double?
    func getAveragePeriodDuration() -> Double?
    func getCycleRegularity() -> CycleRegularity?
}

struct CycleManager: CycleManaging {
    private let maxLookbackCycles = 6
    
    private let minValidCycleLength = 15 //days
    private let maxValidCycleLength = 40 //days
    
    func getNextCycle() -> CyclePrediction? {
        let cycles = CycleRepo.shared.getCycles(for: .year)
        return calculateCycle(from: cycles)
    }
    
    private func calculateCycle(from entries: [Cycle]) -> CyclePrediction? {
        let startDates = entries
            .filter { $0.isStartOfCycle }
            .map { $0.date }
            .sorted()
        
        guard startDates.count >= 2, let lastPeriodDate = startDates.last else {
            return nil
        }
        
        var recentCycleLengths: [Int] = []
        
        for i in (1..<startDates.count).reversed() {
            let current = startDates[i]
            let previous = startDates[i - 1]
            
            if let days = Calendar.current.dateComponents([.day], from: previous, to: current).day {
                if days >= minValidCycleLength && days <= maxValidCycleLength {
                    recentCycleLengths.append(days)
                }
            }
            
            if recentCycleLengths.count >= maxLookbackCycles {
                break
            }
        }
        
        guard !recentCycleLengths.isEmpty else { return nil }
        
        let totalDays = recentCycleLengths.reduce(0, +)
        let averageLength = Double(totalDays) / Double(recentCycleLengths.count)
        
        let predictedCycleDays = Int(round(averageLength))
        
        if let start = Calendar.current.date(byAdding: .day, value: predictedCycleDays, to: lastPeriodDate) {
            return CyclePrediction(startDate: start, length: Int(calculateAveragePeriodDuration(from: entries)))
        }
        
        return nil
    }
    
    func calculateAveragePeriodDuration(from entries: [Cycle]) -> Double {

            // 1. Create a quick lookup set for all dates where a log exists.
            // We normalize to startOfDay to ignore time differences.
            let loggedDates = Set(entries.map { Calendar.current.startOfDay(for: $0.date) })

            // 2. Find the "Anchor" days (where the user explicitly said "Period Started")
            let startDates = entries
                .filter { $0.isStartOfCycle }
                .map { Calendar.current.startOfDay(for: $0.date) }

            guard !startDates.isEmpty else { return 0.0 }

            var periodDurations: [Int] = []

            // 3. For each start date, count the consecutive streak of logs
            for startDate in startDates {
                var duration = 1 // The start day itself counts as Day 1
                var nextDayToCheck = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!

                // Keep checking the next day as long as it exists in our logs
                while loggedDates.contains(nextDayToCheck) {
                    duration += 1
                    nextDayToCheck = Calendar.current.date(byAdding: .day, value: 1, to: nextDayToCheck)!
                }

                periodDurations.append(duration)
            }

            // 5. Calculate Average
            let totalDays = periodDurations.reduce(0, +)
            return Double(totalDays) / Double(periodDurations.count)
        }

    // MARK: - Public Statistics Methods

    func getAverageCycleLength() -> Double? {
        let cycles = CycleRepo.shared.getCycles(for: .year)
        let startDates = cycles
            .filter { $0.isStartOfCycle }
            .map { $0.date }
            .sorted()

        guard startDates.count >= 2 else { return nil }

        var cycleLengths: [Int] = []

        for i in 1..<startDates.count {
            let current = startDates[i]
            let previous = startDates[i - 1]

            if let days = Calendar.current.dateComponents([.day], from: previous, to: current).day {
                if days >= minValidCycleLength && days <= maxValidCycleLength {
                    cycleLengths.append(days)
                }
            }
        }

        guard !cycleLengths.isEmpty else { return nil }

        let total = cycleLengths.reduce(0, +)
        return Double(total) / Double(cycleLengths.count)
    }

    func getAveragePeriodDuration() -> Double? {
        let cycles = CycleRepo.shared.getCycles(for: .year)
        let avgDuration = calculateAveragePeriodDuration(from: cycles)
        return avgDuration > 0 ? avgDuration : nil
    }

    func getCycleRegularity() -> CycleRegularity? {
        let cycles = CycleRepo.shared.getCycles(for: .year)
        let startDates = cycles
            .filter { $0.isStartOfCycle }
            .map { $0.date }
            .sorted()

        // Need at least 3 cycles to determine regularity
        guard startDates.count >= 3 else { return .insufficientData }

        var cycleLengths: [Int] = []

        for i in 1..<startDates.count {
            let current = startDates[i]
            let previous = startDates[i - 1]

            if let days = Calendar.current.dateComponents([.day], from: previous, to: current).day {
                if days >= minValidCycleLength && days <= maxValidCycleLength {
                    cycleLengths.append(days)
                }
            }
        }

        guard cycleLengths.count >= 2 else { return .insufficientData }

        // Calculate standard deviation
        let avg = Double(cycleLengths.reduce(0, +)) / Double(cycleLengths.count)
        let variance = cycleLengths.map { pow(Double($0) - avg, 2) }.reduce(0, +) / Double(cycleLengths.count)
        let stdDev = sqrt(variance)

        // Also check min/max range
        let minLength = cycleLengths.min() ?? 0
        let maxLength = cycleLengths.max() ?? 0
        let range = maxLength - minLength

        // Classify regularity based on variation
        // Regular: stdDev <= 3 days and range <= 6 days
        // Somewhat Regular: stdDev <= 6 days or range <= 10 days
        // Irregular: everything else
        if stdDev <= 3 && range <= 6 {
            return .regular
        } else if stdDev <= 6 || range <= 10 {
            return .somewhatRegular
        } else {
            return .irregular
        }
    }
}

struct MockCycleManager: CycleManaging {
    func getNextCycle() -> CyclePrediction? {
        return CyclePrediction(startDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date(), length: 5)
    }

    func getAverageCycleLength() -> Double? {
        return 28.0
    }

    func getAveragePeriodDuration() -> Double? {
        return 5.0
    }

    func getCycleRegularity() -> CycleRegularity? {
        return .regular
    }
}

struct CyclePrediction {
    let startDate: Date
    let length: Int
}
