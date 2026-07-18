import Foundation

enum CyclePhase: String, CaseIterable, Codable, Sendable {
    case menstrual = "Menstrual"
    case follicular = "Follicular"
    case ovulatory = "Ovulatory"
    case luteal = "Luteal"
}

struct CyclePhaseSummary: Identifiable, Equatable, Sendable {
    var id: String { "\(metricID.rawValue)|\(phase.rawValue)" }
    let metricID: MetricID
    let metricName: String
    let phase: CyclePhase
    let mean: Double
    let observationCount: Int
    let cycleCount: Int
    let differenceFromPersonalMean: Double
}

struct FlareComparison: Identifiable, Equatable, Sendable {
    var id: MetricID { metricID }
    let metricID: MetricID
    let metricName: String
    let flareMean: Double
    let nonFlareMean: Double
    let difference: Double
    let flareDayCount: Int
    let nonFlareDayCount: Int
    let eligibleDayCount: Int
    let limitations: [String]
}

struct ContextAnalysisResult: Equatable, Sendable {
    let phaseSummaries: [CyclePhaseSummary]
    let flareComparisons: [FlareComparison]
    let recordedCycleStartCount: Int
    let limitations: [String]
}

struct ContextAnalysisEngine {
    func analyze(dataset: AnalyticsDataset, recordedCycleStarts: [Date], calendar: Calendar = .current) -> ContextAnalysisResult {
        let starts = Array(Set(recordedCycleStarts.map { calendar.startOfDay(for: $0) })).sorted()
        let phaseAssignments = assignments(between: starts, calendar: calendar)
        let flareStates = booleanValues(dataset.observations(for: MetricCatalog.flareDay.id), calendar: calendar)
        var phases: [CyclePhaseSummary] = []
        var flares: [FlareComparison] = []

        for definition in dataset.definitions where definition.id != MetricCatalog.flareDay.id {
            let values = numericValues(dataset.observations(for: definition.id), calendar: calendar)
            guard !values.isEmpty else { continue }
            let personalMean = values.values.reduce(0, +) / Double(values.count)
            let grouped = Dictionary(grouping: values.compactMap { day, value -> (CyclePhase, Int, Double)? in
                guard let context = phaseAssignments[day] else { return nil }
                return (context.phase, context.cycleIndex, value)
            }, by: { $0.0 })
            for phase in CyclePhase.allCases {
                let group = grouped[phase] ?? []
                let cycles = Set(group.map { $0.1 })
                guard group.count >= 3, cycles.count >= 2 else { continue }
                let mean = group.reduce(0) { $0 + $1.2 } / Double(group.count)
                phases.append(CyclePhaseSummary(metricID: definition.id, metricName: definition.displayName,
                    phase: phase, mean: mean, observationCount: group.count, cycleCount: cycles.count,
                    differenceFromPersonalMean: mean - personalMean))
            }

            let matched = values.compactMap { day, value in flareStates[day].map { ($0, value) } }
            let flare = matched.filter { $0.0 }.map { $0.1 }
            let nonFlare = matched.filter { !$0.0 }.map(\.1)
            guard flare.count >= 3, nonFlare.count >= 3 else { continue }
            let flareMean = flare.reduce(0, +) / Double(flare.count)
            let nonFlareMean = nonFlare.reduce(0, +) / Double(nonFlare.count)
            flares.append(FlareComparison(metricID: definition.id, metricName: definition.displayName,
                flareMean: flareMean, nonFlareMean: nonFlareMean, difference: flareMean - nonFlareMean,
                flareDayCount: flare.count, nonFlareDayCount: nonFlare.count,
                eligibleDayCount: flareStates.count,
                limitations: ["Flare state is used only on days with an explicit daily log.",
                              "This comparison describes recorded days and does not diagnose a condition."]))
        }
        phases.sort { abs($0.differenceFromPersonalMean) > abs($1.differenceFromPersonalMean) }
        flares.sort { abs($0.difference) > abs($1.difference) }
        var limitations = ["Cycle phases are estimated only between explicitly recorded cycle starts.",
                           "No cycle phase is assigned before the first or after the last recorded start."]
        if starts.count < 3 { limitations.append("At least three recorded cycle starts are needed for repeated phase comparisons.") }
        return ContextAnalysisResult(phaseSummaries: phases, flareComparisons: flares,
            recordedCycleStartCount: starts.count, limitations: limitations)
    }

    private func assignments(between starts: [Date], calendar: Calendar) -> [Date: (phase: CyclePhase, cycleIndex: Int)] {
        guard starts.count >= 2 else { return [:] }
        var result: [Date: (CyclePhase, Int)] = [:]
        for index in 0..<(starts.count - 1) {
            let start = starts[index], next = starts[index + 1]
            let length = calendar.dateComponents([.day], from: start, to: next).day ?? 0
            guard (21...45).contains(length) else { continue }
            let ovulation = max(6, length - 14)
            for dayIndex in 0..<length {
                guard let day = calendar.date(byAdding: .day, value: dayIndex, to: start) else { continue }
                let phase: CyclePhase
                if dayIndex <= 4 { phase = .menstrual }
                else if abs(dayIndex - ovulation) <= 1 { phase = .ovulatory }
                else if dayIndex > ovulation + 1 { phase = .luteal }
                else { phase = .follicular }
                result[calendar.startOfDay(for: day)] = (phase, index)
            }
        }
        return result
    }

    private func numericValues(_ observations: [MetricObservation], calendar: Calendar) -> [Date: Double] {
        Dictionary(observations.compactMap { observation in
            guard case .observed(let value) = observation.state, let number = value.numericValue else { return nil }
            return (calendar.startOfDay(for: observation.day), number)
        }, uniquingKeysWith: { _, latest in latest })
    }

    private func booleanValues(_ observations: [MetricObservation], calendar: Calendar) -> [Date: Bool] {
        Dictionary(observations.compactMap { observation in
            guard case .observed(let value) = observation.state else { return nil }
            let flag: Bool?
            switch value { case .boolean(let value): flag = value; case .number(let value): flag = value != 0; default: flag = nil }
            return flag.map { (calendar.startOfDay(for: observation.day), $0) }
        }, uniquingKeysWith: { _, latest in latest })
    }
}

enum BaselinePosition: String, Codable, Sendable { case below, typical, above }

struct PersonalBaseline: Identifiable, Equatable, Sendable {
    var id: MetricID { metricID }
    let metricID: MetricID
    let metricName: String
    let baselineStart: Date
    let baselineEnd: Date
    let baselineObservationCount: Int
    let recentObservationCount: Int
    let center: Double
    let variation: Double
    let recentValue: Double
    let difference: Double
    let position: BaselinePosition
    let isQualifiedByGap: Bool
    let limitations: [String]
}

struct PersonalBaselineConfiguration: Equatable, Sendable {
    var minimumHistoryCount = 28
    var recentObservationCount = 7
    var baselineLookbackDays = 120
    var longGapDays = 30
    var recencyHalfLifeDays = 45.0
}

struct PersonalBaselineEngine {
    func build(definition: MetricDefinition, observations: [MetricObservation],
               definitionChangedAt: Date? = nil,
               configuration: PersonalBaselineConfiguration = PersonalBaselineConfiguration()) -> PersonalBaseline? {
        var values = observations.compactMap { observation -> (Date, Double)? in
            guard case .observed(let value) = observation.state, let number = value.numericValue else { return nil }
            if let changed = definitionChangedAt, observation.day < changed { return nil }
            return (observation.day, number)
        }.sorted { $0.0 < $1.0 }
        guard values.count >= configuration.minimumHistoryCount + configuration.recentObservationCount,
              let latest = values.last?.0 else { return nil }
        let cutoff = Calendar.current.date(byAdding: .day, value: -configuration.baselineLookbackDays, to: latest) ?? .distantPast
        values = values.filter { $0.0 >= cutoff }
        guard values.count >= configuration.minimumHistoryCount + configuration.recentObservationCount else { return nil }
        let recent = Array(values.suffix(configuration.recentObservationCount))
        let history = Array(values.dropLast(configuration.recentObservationCount))
        guard history.count >= configuration.minimumHistoryCount else { return nil }

        let weights = history.map { exp(-max(0, latest.timeIntervalSince($0.0) / 86_400) * log(2) / configuration.recencyHalfLifeDays) }
        let center = weightedMedian(Array(zip(history.map(\.1), weights)))
        let variation = median(history.map { abs($0.1 - center) })
        let recentValue = median(recent.map(\.1))
        let band = max(0.1, variation * 3)
        let position: BaselinePosition = recentValue > center + band ? .above : (recentValue < center - band ? .below : .typical)
        let largestGap = zip(values, values.dropFirst()).map { pair in
            pair.1.0.timeIntervalSince(pair.0.0) / 86_400
        }.max() ?? 0
        var limitations = ["The baseline uses a recency-weighted median, so isolated outliers have limited influence.",
                           "Above or below means different from your recorded history, not medically good or bad."]
        if definitionChangedAt != nil { limitations.append("Only observations after the metric definition changed were used.") }
        if largestGap > Double(configuration.longGapDays) { limitations.append("A tracking gap longer than \(configuration.longGapDays) days qualifies this baseline.") }
        return PersonalBaseline(metricID: definition.id, metricName: definition.displayName,
            baselineStart: history.first!.0, baselineEnd: history.last!.0,
            baselineObservationCount: history.count, recentObservationCount: recent.count,
            center: center, variation: variation, recentValue: recentValue, difference: recentValue - center,
            position: position, isQualifiedByGap: largestGap > Double(configuration.longGapDays), limitations: limitations)
    }

    private func weightedMedian(_ values: [(Double, Double)]) -> Double {
        let sorted = values.sorted { $0.0 < $1.0 }
        let threshold = sorted.reduce(0) { $0 + $1.1 } / 2
        var cumulative = 0.0
        for value in sorted { cumulative += value.1; if cumulative >= threshold { return value.0 } }
        return sorted.last?.0 ?? 0
    }

    private func median(_ values: [Double]) -> Double {
        let sorted = values.sorted(), middle = sorted.count / 2
        guard !sorted.isEmpty else { return 0 }
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}
