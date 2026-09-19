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
    func getPredictionAnalysis() -> CyclePredictionAnalysis
    func getAverageCycleLength() -> Double?
    func getAveragePeriodDuration() -> Double?
    func getCycleRegularity() -> CycleRegularity?
}

struct CycleManager: CycleManaging {
    private let maxLookbackCycles = 6
    private let minValidCycleLength = 15 //days
    private let maxValidCycleLength = 40 //days
    private let cycleRepository: CycleRepositoryProtocol
    private let calendar: Calendar

    init(
        cycleRepository: CycleRepositoryProtocol = CycleRepo.shared,
        calendar: Calendar = .current
    ) {
        self.cycleRepository = cycleRepository
        self.calendar = calendar
    }

    func getNextCycle() -> CyclePrediction? {
        getPredictionAnalysis().prediction
    }

    func getPredictionAnalysis() -> CyclePredictionAnalysis {
        analyze(entries: cycleRepository.getAllCycles())
    }

    func analyze(entries: [Cycle]) -> CyclePredictionAnalysis {
        let startDates = uniqueDays(entries
            .filter { $0.isStartOfCycle }
            .map(\.date))

        var acceptedIntervals: [Int] = []
        var excludedIntervals: [CycleIntervalExclusion] = []

        if startDates.count >= 2 {
            for index in 1..<startDates.count {
                let previous = startDates[index - 1]
                let current = startDates[index]
                let days = calendar.dateComponents([.day], from: previous, to: current).day ?? 0
                if (minValidCycleLength...maxValidCycleLength).contains(days) {
                    acceptedIntervals.append(days)
                } else {
                    excludedIntervals.append(CycleIntervalExclusion(
                        earlierStart: previous,
                        laterStart: current,
                        days: days,
                        reason: days < minValidCycleLength
                            ? "Starts are less than \(minValidCycleLength) days apart"
                            : "Starts are more than \(maxValidCycleLength) days apart"
                    ))
                }
            }
        }

        let recentIntervals = Array(acceptedIntervals.suffix(maxLookbackCycles))
        let durationResult = completedPeriodDurations(entries: entries, starts: startDates)
        var prediction: CyclePrediction?
        if let lastStart = startDates.last, !recentIntervals.isEmpty {
            let average = Double(recentIntervals.reduce(0, +)) / Double(recentIntervals.count)
            if let predictedStart = calendar.date(
                byAdding: .day,
                value: Int(average.rounded()),
                to: lastStart
            ) {
                let duration = durationResult.durations.isEmpty
                    ? nil
                    : Int((Double(durationResult.durations.reduce(0, +))
                        / Double(durationResult.durations.count)).rounded())
                prediction = CyclePrediction(startDate: predictedStart, length: duration)
            }
        }

        return CyclePredictionAnalysis(
            prediction: prediction,
            totalEntries: entries.count,
            detectedStarts: startDates,
            acceptedIntervals: acceptedIntervals,
            excludedIntervals: excludedIntervals,
            completedPeriodDurations: durationResult.durations,
            incompletePeriodCount: durationResult.incompleteCount,
            validCycleRange: minValidCycleLength...maxValidCycleLength
        )
    }

    func calculateAveragePeriodDuration(from entries: [Cycle]) -> Double {
        let starts = uniqueDays(entries.filter(\.isStartOfCycle).map(\.date))
        let durations = completedPeriodDurations(entries: entries, starts: starts).durations
        guard !durations.isEmpty else { return 0 }
        return Double(durations.reduce(0, +)) / Double(durations.count)
    }

    // MARK: - Public Statistics Methods

    func getAverageCycleLength() -> Double? {
        let intervals = getPredictionAnalysis().acceptedIntervals
        guard !intervals.isEmpty else { return nil }
        return Double(intervals.reduce(0, +)) / Double(intervals.count)
    }

    func getAveragePeriodDuration() -> Double? {
        let durations = getPredictionAnalysis().completedPeriodDurations
        guard !durations.isEmpty else { return nil }
        return Double(durations.reduce(0, +)) / Double(durations.count)
    }

    func getCycleRegularity() -> CycleRegularity? {
        let cycleLengths = getPredictionAnalysis().acceptedIntervals
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

    private func completedPeriodDurations(
        entries: [Cycle],
        starts: [Date]
    ) -> (durations: [Int], incompleteCount: Int) {
        guard !starts.isEmpty else { return ([], 0) }
        let normalizedEntries = entries.map { entry in
            (date: calendar.startOfDay(for: entry.date), entry: entry)
        }
        var durations: [Int] = []
        var incompleteCount = 0

        for (index, start) in starts.enumerated() {
            let nextStart = index + 1 < starts.count ? starts[index + 1] : nil
            let periodEntries = normalizedEntries
                .filter { item in
                    item.date >= start && (nextStart == nil || item.date < nextStart!)
                }
                .sorted { $0.date < $1.date }

            if let explicitEnd = periodEntries.first(where: { $0.entry.isEndOfCycle == true })?.date,
               let daySpan = calendar.dateComponents([.day], from: start, to: explicitEnd).day,
               (0...13).contains(daySpan) {
                durations.append(daySpan + 1)
                continue
            }

            let days = uniqueDays(periodEntries.map(\.date))
            let hasGap = zip(days, days.dropFirst()).contains { previous, current in
                (calendar.dateComponents([.day], from: previous, to: current).day ?? 0) > 1
            }
            if nextStart != nil, !days.isEmpty, !hasGap, days.count <= 14 {
                durations.append(days.count)
            } else {
                incompleteCount += 1
            }
        }
        return (durations, incompleteCount)
    }

    private func uniqueDays(_ dates: [Date]) -> [Date] {
        Array(Set(dates.map { calendar.startOfDay(for: $0) })).sorted()
    }
}

struct MockCycleManager: CycleManaging {
    func getNextCycle() -> CyclePrediction? {
        return CyclePrediction(startDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date(), length: 5)
    }

    func getPredictionAnalysis() -> CyclePredictionAnalysis {
        CyclePredictionAnalysis(
            prediction: getNextCycle(),
            totalEntries: 10,
            detectedStarts: [Date(), Date()],
            acceptedIntervals: [28],
            excludedIntervals: [],
            completedPeriodDurations: [5],
            incompletePeriodCount: 0,
            validCycleRange: 15...40
        )
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
    let length: Int?
}

struct CycleIntervalExclusion: Identifiable {
    let id = UUID()
    let earlierStart: Date
    let laterStart: Date
    let days: Int
    let reason: String
}

struct CyclePredictionAnalysis {
    let prediction: CyclePrediction?
    let totalEntries: Int
    let detectedStarts: [Date]
    let acceptedIntervals: [Int]
    let excludedIntervals: [CycleIntervalExclusion]
    let completedPeriodDurations: [Int]
    let incompletePeriodCount: Int
    let validCycleRange: ClosedRange<Int>

    var requirementText: String {
        "Prediction needs 2 marked starts that are \(validCycleRange.lowerBound)–\(validCycleRange.upperBound) days apart."
    }

    var unavailableExplanation: String? {
        guard prediction == nil else { return nil }
        if totalEntries == 0 {
            return "No period days have been logged yet. \(requirementText)"
        }
        if detectedStarts.isEmpty {
            return "Period days exist, but none are marked as a start. Edit the first day of each period and turn on Period Started."
        }
        if detectedStarts.count == 1 {
            return "1 cycle start is marked. Mark the start of one more period to create an interval."
        }
        if acceptedIntervals.isEmpty {
            return "The marked starts are outside the accepted \(validCycleRange.lowerBound)–\(validCycleRange.upperBound) day range. Review the dates below."
        }
        return requirementText
    }
}
