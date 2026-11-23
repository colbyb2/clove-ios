import Foundation

struct CycleDayPoint: Identifiable {
    var id: Int { day }
    let day: Int
    let mean: Double?
    let observationCount: Int
    let eligibleCycleCount: Int
    let flowCount: Int
    let noFlowCount: Int
    let fertilityCount: Int
    let ovulationCount: Int
}

struct CycleFlowGroup: Identifiable {
    var id: Bool { hasFlow }
    let hasFlow: Bool
    let mean: Double
    let observationCount: Int
}

struct CycleDayAnalysis {
    let points: [CycleDayPoint]
    let flowGroups: [CycleFlowGroup]
    let completedCycleCount: Int
}

/// Descriptive comparisons of explicitly recorded days. Cycle boundaries use calendar
/// days and all marked starts, independently of prediction eligibility or phase estimates.
struct CycleDayAnalysisEngine {
    func analyze(observations: [MetricObservation], entries: [Cycle], interval: DateInterval,
                 binary: Bool = false, calendar: Calendar = .current) -> CycleDayAnalysis {
        let starts = Array(Set(entries.filter(\.isStartOfCycle).map { calendar.startOfDay(for: $0.date) })).sorted()
        let values = Dictionary(observations.compactMap { observation -> (Date, Double)? in
            guard case .observed(let value) = observation.state,
                  let number = value.numericValue, number.isFinite else { return nil }
            return (calendar.startOfDay(for: observation.day), binary ? number * 100 : number)
        }, uniquingKeysWith: { _, latest in latest })
        let records = Dictionary(grouping: entries, by: { calendar.startOfDay(for: $0.date) })
        var samples: [Int: [Double]] = [:]
        var eligible: [Int: Int] = [:]
        var flow: [Int: Int] = [:], noFlow: [Int: Int] = [:]
        var fertility: [Int: Int] = [:], ovulation: [Int: Int] = [:]
        var groups: [Bool: [Double]] = [:]
        var completed = 0
        if starts.count >= 2 {
            for index in 0..<(starts.count - 1) {
                let start = starts[index], end = starts[index + 1]
                // A future marked start cannot complete a cycle yet.
                guard end <= calendar.startOfDay(for: Date()), start < interval.end, end > interval.start else { continue }
                completed += 1
                let firstDay = max(start, calendar.startOfDay(for: interval.start))
                let lastDay = min(end, interval.end)
                var date = firstDay
                while date < lastDay {
                    let day = (calendar.dateComponents([.day], from: start, to: date).day ?? 0) + 1
                    eligible[day, default: 0] += 1
                    if let number = values[date] { samples[day, default: []].append(number) }
                    let dayEntries = records[date] ?? []
                    // Latest explicit flow wins if older data contains multiple entries per day.
                    let explicitFlow = dayEntries.filter { $0.flow != .notRecorded }.max { $0.date < $1.date }?.flow
                    if let explicitFlow {
                        if explicitFlow.isBleeding { flow[day, default: 0] += 1 }
                        else { noFlow[day, default: 0] += 1 }
                        if let number = values[date] { groups[explicitFlow.isBleeding, default: []].append(number) }
                    }
                    if dayEntries.contains(where: { $0.fertilitySigns == true }) { fertility[day, default: 0] += 1 }
                    if dayEntries.contains(where: { $0.ovulation == true }) { ovulation[day, default: 0] += 1 }
                    guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
                    date = next
                }
            }
        }
        let points = eligible.keys.sorted().map { day in
            let numbers = samples[day] ?? []
            return CycleDayPoint(day: day, mean: numbers.isEmpty ? nil : numbers.reduce(0, +) / Double(numbers.count),
                observationCount: numbers.count, eligibleCycleCount: eligible[day] ?? 0,
                flowCount: flow[day] ?? 0, noFlowCount: noFlow[day] ?? 0,
                fertilityCount: fertility[day] ?? 0, ovulationCount: ovulation[day] ?? 0)
        }
        let flowGroups = [true, false].compactMap { state -> CycleFlowGroup? in
            guard let numbers = groups[state], !numbers.isEmpty else { return nil }
            return CycleFlowGroup(hasFlow: state, mean: numbers.reduce(0, +) / Double(numbers.count), observationCount: numbers.count)
        }
        return CycleDayAnalysis(points: points, flowGroups: flowGroups, completedCycleCount: completed)
    }
}
