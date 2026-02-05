//
//  CycleManager.swift
//  Clove
//
//  Created by Colby Brown on 2/4/26.
//

import SwiftUI

protocol CycleManaging {
    func getNextCycle() -> CyclePrediction?
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
}

struct MockCycleManager: CycleManaging {
    func getNextCycle() -> CyclePrediction? {
        return CyclePrediction(startDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date(), length: 5)
    }
}

struct CyclePrediction {
    let startDate: Date
    let length: Int
}
