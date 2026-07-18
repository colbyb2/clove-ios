import Foundation

enum RelationshipValue: Equatable, Sendable {
    case numeric(Double)
    case binary(Bool)
    case category(String)

    var numeric: Double? {
        switch self {
        case .numeric(let value): return value
        case .binary(let value): return value ? 1 : 0
        case .category: return nil
        }
    }

    var category: String {
        switch self {
        case .numeric(let value): return String(value)
        case .binary(let value): return value ? "Yes" : "No"
        case .category(let value): return value
        }
    }
}

struct AlignedMetricPair: Equatable, Sendable, Identifiable {
    var id: Date { factorDay }
    let factorDay: Date
    let outcomeDay: Date
    let factor: RelationshipValue
    let outcome: RelationshipValue
    let qualityFlags: Set<MetricQualityFlag>
}

struct PairAlignmentCoverage: Equatable, Sendable {
    let eligibleDayCount: Int
    let factorObservedDayCount: Int
    let outcomeObservedDayCount: Int
    let matchedDayCount: Int
    let excludedDayCount: Int

    var matchedFraction: Double {
        guard eligibleDayCount > 0 else { return 0 }
        return Double(matchedDayCount) / Double(eligibleDayCount)
    }
}

struct PairAlignmentResult: Equatable, Sendable {
    /// Positive lag means the factor is matched with an outcome recorded this many days later.
    let lagDays: Int
    let pairs: [AlignedMetricPair]
    let coverage: PairAlignmentCoverage
    let qualityFlags: Set<MetricQualityFlag>
}

struct PairAlignmentEngine: Sendable {
    let normalizer: MetricDayNormalizer

    init(calendar: Calendar = Calendar(identifier: .gregorian), timeZone: TimeZone = .current) {
        normalizer = MetricDayNormalizer(calendar: calendar, timeZone: timeZone)
    }

    func align(
        factor: MetricDefinition,
        outcome: MetricDefinition,
        dataset: AnalyticsDataset,
        lagDays: Int = 0
    ) -> PairAlignmentResult {
        let factorValues = dayValues(dataset.observations(for: factor.id), definition: factor)
        let outcomeValues = dayValues(dataset.observations(for: outcome.id), definition: outcome)
        var pairs: [AlignedMetricPair] = []

        for entry in factorValues.values.sorted(by: { $0.day < $1.day }) {
            guard let outcomeDay = normalizer.calendar.date(byAdding: .day, value: lagDays, to: entry.day) else { continue }
            let key = normalizer.dayKey(for: outcomeDay)
            guard let matched = outcomeValues[key] else { continue }
            pairs.append(AlignedMetricPair(
                factorDay: entry.day,
                outcomeDay: matched.day,
                factor: entry.value,
                outcome: matched.value,
                qualityFlags: entry.flags.union(matched.flags)
            ))
        }

        let eligible = possibleDays(in: dataset.interval, lagDays: lagDays)
        return PairAlignmentResult(
            lagDays: lagDays,
            pairs: pairs,
            coverage: PairAlignmentCoverage(
                eligibleDayCount: eligible,
                factorObservedDayCount: factorValues.count,
                outcomeObservedDayCount: outcomeValues.count,
                matchedDayCount: pairs.count,
                excludedDayCount: max(0, eligible - pairs.count)
            ),
            qualityFlags: Set(pairs.flatMap(\.qualityFlags))
        )
    }

    private struct DayValue {
        let day: Date
        let value: RelationshipValue
        let flags: Set<MetricQualityFlag>
    }

    private func dayValues(_ observations: [MetricObservation], definition: MetricDefinition) -> [String: DayValue] {
        var result: [String: DayValue] = [:]
        for observation in observations.sorted(by: { $0.timestamp < $1.timestamp }) {
            guard let value = relationshipValue(observation.state, definition: definition) else { continue }
            let day = normalizer.day(containing: observation.day)
            result[normalizer.dayKey(for: day)] = DayValue(day: day, value: value, flags: observation.qualityFlags)
        }
        return result
    }

    private func relationshipValue(_ state: MetricObservationState, definition: MetricDefinition) -> RelationshipValue? {
        switch state {
        case .missing, .notApplicable:
            return nil
        case .explicitNone:
            guard definition.unrecordedDayPolicy == .explicitNone || definition.unrecordedDayPolicy == .zero else { return nil }
            return definition.measurementLevel == .binary || definition.measurementLevel == .event ? .binary(false) : .numeric(0)
        case .observed(let value):
            switch value {
            case .number(let number): return .numeric(number)
            case .boolean(let boolean): return .binary(boolean)
            case .category(let category): return .category(category)
            case .ratio(let numerator, let denominator):
                guard denominator > 0 else { return nil }
                return .numeric(Double(numerator) / Double(denominator) * 100)
            case .distribution(let buckets):
                guard !buckets.isEmpty else { return nil }
                if definition.measurementLevel == .ordinal {
                    let weighted = buckets.compactMap { bucket -> (Double, Int)? in
                        let raw = bucket.value.replacingOccurrences(of: "number:", with: "")
                        guard let value = Double(raw) else { return nil }
                        return (value, bucket.count)
                    }
                    let count = weighted.reduce(0) { $0 + $1.1 }
                    guard count > 0 else { return nil }
                    return .numeric(weighted.reduce(0) { $0 + $1.0 * Double($1.1) } / Double(count))
                }
                return buckets.max { lhs, rhs in
                    lhs.count == rhs.count ? lhs.value > rhs.value : lhs.count < rhs.count
                }.map { .category($0.value.replacingOccurrences(of: "category:", with: "")) }
            }
        }
    }

    private func possibleDays(in interval: DateInterval, lagDays: Int) -> Int {
        var count = 0
        var day = normalizer.day(containing: interval.start)
        while day < interval.end {
            if let shifted = normalizer.calendar.date(byAdding: .day, value: lagDays, to: day),
               shifted >= interval.start, shifted < interval.end { count += 1 }
            guard let next = normalizer.calendar.date(byAdding: .day, value: 1, to: day), next > day else { break }
            day = next
        }
        return count
    }
}

enum RelationshipMethod: String, Codable, CaseIterable, Sendable {
    case pearson
    case spearman
    case pointBiserial
    case phi
    case cramersV
    case correlationRatio

    var displayName: String {
        switch self {
        case .pearson: return "Pearson correlation"
        case .spearman: return "Spearman rank correlation"
        case .pointBiserial: return "Point-biserial correlation"
        case .phi: return "Phi coefficient"
        case .cramersV: return "Cramér’s V"
        case .correlationRatio: return "Correlation ratio (η)"
        }
    }

    var signed: Bool { self != .cramersV && self != .correlationRatio }
}

enum RelationshipEvidenceQuality: String, Sendable {
    case insufficient = "Insufficient"
    case limited = "Limited"
    case fair = "Fair"
    case strong = "Strong"
}

struct RelationshipEstimate: Equatable, Sendable {
    let method: RelationshipMethod
    let effect: Double?
    let confidenceInterval: ClosedRange<Double>?
    let pValue: Double?
    let sampleCount: Int
    let minimumSampleCount: Int
    let evidenceQuality: RelationshipEvidenceQuality
    let limitations: [String]

    var isSufficient: Bool { effect != nil && sampleCount >= minimumSampleCount }
    var strength: String {
        guard let effect else { return "Unavailable" }
        switch abs(effect) {
        case 0.7...: return "Strong"
        case 0.4..<0.7: return "Moderate"
        case 0.2..<0.4: return "Weak"
        default: return "Very weak"
        }
    }
}

struct RelationshipMethodSelector {
    func select(factor: MetricDefinition, outcome: MetricDefinition) -> RelationshipMethod? {
        let lhs = factor.measurementLevel
        let rhs = outcome.measurementLevel
        if lhs == .categorical && rhs == .categorical { return .cramersV }
        if lhs == .binary && rhs == .binary { return .phi }
        if (lhs == .binary && rhs.isNumeric) || (rhs == .binary && lhs.isNumeric) { return .pointBiserial }
        if lhs == .categorical && rhs.isNumeric || rhs == .categorical && lhs.isNumeric { return .correlationRatio }
        if lhs == .ordinal || rhs == .ordinal { return lhs.isNumeric && rhs.isNumeric ? .spearman : nil }
        if lhs.isNumeric && rhs.isNumeric { return .pearson }
        return nil
    }
}

private extension MetricMeasurementLevel {
    var isNumeric: Bool { [.continuous, .ordinal, .count, .percentage].contains(self) }
}

struct RelationshipStatisticsEngine {
    func estimate(
        alignment: PairAlignmentResult,
        factor: MetricDefinition,
        outcome: MetricDefinition,
        forcedMethod: RelationshipMethod? = nil
    ) -> RelationshipEstimate {
        guard let method = forcedMethod ?? RelationshipMethodSelector().select(factor: factor, outcome: outcome) else {
            return RelationshipEstimate(method: .pearson, effect: nil, confidenceInterval: nil, pValue: nil,
                                        sampleCount: alignment.pairs.count, minimumSampleCount: 14,
                                        evidenceQuality: .insufficient,
                                        limitations: ["This combination does not yet have a supported comparison method."])
        }
        let minimum = max(14, factor.minimumSamples.relationship, outcome.minimumSamples.relationship)
        let n = alignment.pairs.count
        guard n >= minimum else {
            return RelationshipEstimate(method: method, effect: nil, confidenceInterval: nil, pValue: nil,
                                        sampleCount: n, minimumSampleCount: minimum, evidenceQuality: .insufficient,
                                        limitations: ["At least \(minimum) matching recorded days are required; \(n) are available."])
        }

        let effect: Double?
        switch method {
        case .pearson, .pointBiserial, .phi:
            effect = pearson(alignment.pairs.compactMap(numericPair))
        case .spearman:
            let values = alignment.pairs.compactMap(numericPair)
            effect = pearson(Array(zip(ranks(values.map(\.0)), ranks(values.map(\.1)))))
        case .cramersV:
            effect = cramersV(alignment.pairs.map { ($0.factor.category, $0.outcome.category) })
        case .correlationRatio:
            effect = correlationRatio(alignment.pairs)
        }

        guard let effect, effect.isFinite else {
            return RelationshipEstimate(method: method, effect: nil, confidenceInterval: nil, pValue: nil,
                                        sampleCount: n, minimumSampleCount: minimum, evidenceQuality: .insufficient,
                                        limitations: ["One metric did not vary enough to estimate a relationship."])
        }

        let interval = method.signed ? fisherInterval(effect: effect, count: n) : bootstrapInterval(method: method, pairs: alignment.pairs)
        let p = method == .cramersV ? nil : correlationPValue(effect: effect, count: n)
        var limitations = ["This is an association, not evidence that one metric caused the other."]
        if alignment.coverage.matchedFraction < 0.5 { limitations.append("Fewer than half of eligible days had both metrics recorded.") }
        if !alignment.qualityFlags.isEmpty { limitations.append("Some source values required normalization or daily reduction.") }
        if [.pearson, .pointBiserial].contains(method), outlierSensitive(alignment.pairs, fullEffect: effect) {
            limitations.append("The estimate changes noticeably when extreme values are removed, so it may be outlier-sensitive.")
        }
        let quality: RelationshipEvidenceQuality = alignment.coverage.matchedFraction >= 0.75 && n >= 30 ? .strong :
            (alignment.coverage.matchedFraction >= 0.5 && n >= 20 ? .fair : .limited)
        return RelationshipEstimate(method: method, effect: effect, confidenceInterval: interval, pValue: p,
                                    sampleCount: n, minimumSampleCount: minimum, evidenceQuality: quality,
                                    limitations: limitations)
    }

    private func numericPair(_ pair: AlignedMetricPair) -> (Double, Double)? {
        guard let lhs = pair.factor.numeric, let rhs = pair.outcome.numeric else { return nil }
        return (lhs, rhs)
    }

    private func pearson(_ values: [(Double, Double)]) -> Double? {
        guard values.count > 2 else { return nil }
        let count = Double(values.count)
        let mx = values.reduce(0) { $0 + $1.0 } / count
        let my = values.reduce(0) { $0 + $1.1 } / count
        let numerator = values.reduce(0) { $0 + ($1.0 - mx) * ($1.1 - my) }
        let sx = values.reduce(0) { $0 + pow($1.0 - mx, 2) }
        let sy = values.reduce(0) { $0 + pow($1.1 - my, 2) }
        guard sx > 0, sy > 0 else { return nil }
        return max(-1, min(1, numerator / sqrt(sx * sy)))
    }

    private func ranks(_ values: [Double]) -> [Double] {
        let indexed = values.enumerated().sorted { $0.element < $1.element }
        var result = Array(repeating: 0.0, count: values.count)
        var index = 0
        while index < indexed.count {
            var end = index + 1
            while end < indexed.count && indexed[end].element == indexed[index].element { end += 1 }
            let averageRank = (Double(index + 1) + Double(end)) / 2
            for position in index..<end { result[indexed[position].offset] = averageRank }
            index = end
        }
        return result
    }

    private func cramersV(_ values: [(String, String)]) -> Double? {
        let rows = Array(Set(values.map(\.0))).sorted()
        let columns = Array(Set(values.map(\.1))).sorted()
        guard rows.count > 1, columns.count > 1 else { return nil }
        var table = Array(repeating: Array(repeating: 0.0, count: columns.count), count: rows.count)
        for value in values {
            if let row = rows.firstIndex(of: value.0), let column = columns.firstIndex(of: value.1) { table[row][column] += 1 }
        }
        let n = Double(values.count)
        let rowTotals = table.map { $0.reduce(0, +) }
        let columnTotals = columns.indices.map { column in table.reduce(0) { $0 + $1[column] } }
        var chiSquared = 0.0
        for row in rows.indices { for column in columns.indices {
            let expected = rowTotals[row] * columnTotals[column] / n
            if expected > 0 { chiSquared += pow(table[row][column] - expected, 2) / expected }
        }}
        let denominator = n * Double(min(rows.count - 1, columns.count - 1))
        return denominator > 0 ? sqrt(chiSquared / denominator) : nil
    }

    private func correlationRatio(_ pairs: [AlignedMetricPair]) -> Double? {
        let factorCategorical = pairs.first?.factor.numeric == nil
        let values: [(String, Double)] = pairs.compactMap { pair in
            if factorCategorical, let number = pair.outcome.numeric { return (pair.factor.category, number) }
            if let number = pair.factor.numeric { return (pair.outcome.category, number) }
            return nil
        }
        guard values.count > 2 else { return nil }
        let mean = values.reduce(0) { $0 + $1.1 } / Double(values.count)
        let total = values.reduce(0) { $0 + pow($1.1 - mean, 2) }
        guard total > 0 else { return nil }
        let between = Dictionary(grouping: values, by: \.0).values.reduce(0.0) { sum, group in
            let groupMean = group.reduce(0) { $0 + $1.1 } / Double(group.count)
            return sum + Double(group.count) * pow(groupMean - mean, 2)
        }
        return sqrt(between / total)
    }

    private func fisherInterval(effect: Double, count: Int) -> ClosedRange<Double>? {
        guard count > 3, abs(effect) < 1 else { return effect...effect }
        let z = atanh(effect)
        let margin = 1.96 / sqrt(Double(count - 3))
        return tanh(z - margin)...tanh(z + margin)
    }

    private func bootstrapInterval(method: RelationshipMethod, pairs: [AlignedMetricPair]) -> ClosedRange<Double>? {
        guard pairs.count > 3 else { return nil }
        var generator = DeterministicGenerator(state: UInt64(pairs.count) &* 0x9E3779B97F4A7C15)
        var estimates: [Double] = []
        for _ in 0..<400 {
            let sample = (0..<pairs.count).map { _ in pairs[Int(generator.next() % UInt64(pairs.count))] }
            let value: Double?
            switch method {
            case .cramersV: value = cramersV(sample.map { ($0.factor.category, $0.outcome.category) })
            case .correlationRatio: value = correlationRatio(sample)
            default: value = nil
            }
            if let value, value.isFinite { estimates.append(value) }
        }
        guard estimates.count >= 100 else { return nil }
        estimates.sort()
        return estimates[Int(Double(estimates.count - 1) * 0.025)]...estimates[Int(Double(estimates.count - 1) * 0.975)]
    }

    private func outlierSensitive(_ pairs: [AlignedMetricPair], fullEffect: Double) -> Bool {
        let values = pairs.compactMap(numericPair)
        guard values.count >= 20 else { return false }
        let xs = values.map(\.0).sorted(), ys = values.map(\.1).sorted()
        let lower = Int(Double(values.count) * 0.05)
        let upper = min(values.count - 1, Int(Double(values.count) * 0.95))
        let trimmed = values.filter { $0.0 >= xs[lower] && $0.0 <= xs[upper] && $0.1 >= ys[lower] && $0.1 <= ys[upper] }
        guard let robust = pearson(trimmed) else { return false }
        return abs(robust - fullEffect) >= 0.15
    }

    private func correlationPValue(effect: Double, count: Int) -> Double? {
        guard count > 2, abs(effect) < 1 else { return abs(effect) == 1 ? 0 : nil }
        let degrees = Double(count - 2)
        let t = abs(effect) * sqrt(degrees / max(1e-15, 1 - effect * effect))
        let x = degrees / (degrees + t * t)
        return min(1, max(0, regularizedBeta(x, degrees / 2, 0.5)))
    }

    private func regularizedBeta(_ x: Double, _ a: Double, _ b: Double) -> Double {
        if x <= 0 { return 0 }; if x >= 1 { return 1 }
        let front = exp(logGamma(a + b) - logGamma(a) - logGamma(b) + a * log(x) + b * log(1 - x))
        return x < (a + 1) / (a + b + 2) ? front * betaFraction(x, a, b) / a : 1 - front * betaFraction(1 - x, b, a) / b
    }

    private func betaFraction(_ x: Double, _ a: Double, _ b: Double) -> Double {
        let maxIterations = 200
        let epsilon = 3e-14
        let floor = 1e-300
        let qab = a + b, qap = a + 1, qam = a - 1
        var c = 1.0
        var d = 1 - qab * x / qap
        if abs(d) < floor { d = floor }; d = 1 / d
        var h = d
        for m in 1...maxIterations {
            let m2 = Double(2 * m), md = Double(m)
            var aa = md * (b - md) * x / ((qam + m2) * (a + m2))
            d = 1 + aa * d; if abs(d) < floor { d = floor }
            c = 1 + aa / c; if abs(c) < floor { c = floor }
            d = 1 / d; h *= d * c
            aa = -(a + md) * (qab + md) * x / ((a + m2) * (qap + m2))
            d = 1 + aa * d; if abs(d) < floor { d = floor }
            c = 1 + aa / c; if abs(c) < floor { c = floor }
            d = 1 / d
            let delta = d * c; h *= delta
            if abs(delta - 1) < epsilon { break }
        }
        return h
    }

    private func logGamma(_ value: Double) -> Double {
        let coefficients = [676.5203681218851, -1259.1392167224028, 771.32342877765313,
                            -176.61502916214059, 12.507343278686905, -0.13857109526572012,
                            9.9843695780195716e-6, 1.5056327351493116e-7]
        if value < 0.5 { return log(.pi) - log(sin(.pi * value)) - logGamma(1 - value) }
        let z = value - 1
        var x = 0.99999999999980993
        for (index, coefficient) in coefficients.enumerated() { x += coefficient / (z + Double(index) + 1) }
        let t = z + Double(coefficients.count) - 0.5
        return 0.5 * log(2 * .pi) + (z + 0.5) * log(t) - t + log(x)
    }
}

private struct DeterministicGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

struct LagRelationshipPoint: Equatable, Sendable, Identifiable {
    var id: Int { lagDays }
    let lagDays: Int
    let estimate: RelationshipEstimate
    let coverage: PairAlignmentCoverage
}

struct LagRelationshipProfile: Equatable, Sendable {
    let points: [LagRelationshipPoint]
    let bestSupported: LagRelationshipPoint?
    let limitations: [String]
}

struct LaggedRelationshipEngine {
    func analyze(factor: MetricDefinition, outcome: MetricDefinition, dataset: AnalyticsDataset, range: ClosedRange<Int> = -7...7,
                 normalizer: PairAlignmentEngine = PairAlignmentEngine()) -> LagRelationshipProfile {
        let statistics = RelationshipStatisticsEngine()
        let points = range.map { lag -> LagRelationshipPoint in
            let alignment = normalizer.align(factor: factor, outcome: outcome, dataset: dataset, lagDays: lag)
            return LagRelationshipPoint(lagDays: lag, estimate: statistics.estimate(alignment: alignment, factor: factor, outcome: outcome), coverage: alignment.coverage)
        }
        let supported = points.filter { $0.estimate.isSufficient }
        let best = supported.max { abs($0.estimate.effect ?? 0) < abs($1.estimate.effect ?? 0) }
        return LagRelationshipProfile(points: points, bestSupported: best, limitations: [
            "Positive lag means the factor was recorded before the outcome.",
            "Fifteen lags were explored; treat the strongest lag as exploratory, not definitive.",
            "Lagged association does not establish causation."
        ])
    }
}

struct EventOutcomeResult: Equatable, Sendable {
    let outcomeOffsetDays: Int
    let exposedCount: Int
    let controlCount: Int
    let exposedMean: Double?
    let controlMean: Double?
    let meanDifference: Double?
    let confidenceInterval: ClosedRange<Double>?
    let limitations: [String]
}

struct EventOutcomeEngine {
    let normalizer: MetricDayNormalizer

    init(calendar: Calendar = Calendar(identifier: .gregorian), timeZone: TimeZone = .current) {
        normalizer = MetricDayNormalizer(calendar: calendar, timeZone: timeZone)
    }

    func analyze(event: MetricDefinition, outcome: MetricDefinition, dataset: AnalyticsDataset, outcomeOffsetDays: Int) -> EventOutcomeResult {
        let rawEventDates = dataset.rawEvents.filter { $0.metricID == event.id }.map(\.day)
        let observationEventDates = dataset.observations(for: event.id).compactMap { observation -> Date? in
            guard case .observed(let value) = observation.state else { return nil }
            if case .boolean(false) = value { return nil }
            return observation.day
        }
        // Some occurrence adapters expose canonical daily observations while their richer raw
        // event belongs to the family count metric. The canonical observation is still a valid
        // exposure date and preserves stable identity across renames.
        let exposureDates = rawEventDates.isEmpty ? observationEventDates : rawEventDates
        let eventDays = Set(exposureDates.map { normalizer.dayKey(for: $0) })
        let values = Dictionary(uniqueKeysWithValues: dataset.observations(for: outcome.id).compactMap { observation -> (String, Double)? in
            guard case .observed(let value) = observation.state, let number = value.numericValue else { return nil }
            return (normalizer.dayKey(for: observation.day), number)
        })
        var exposed: [Double] = []
        var exposedOutcomeKeys = Set<String>()
        for exposureDate in exposureDates {
            guard let day = normalizer.calendar.date(byAdding: .day, value: outcomeOffsetDays, to: exposureDate) else { continue }
            let key = normalizer.dayKey(for: day)
            if exposedOutcomeKeys.insert(key).inserted, let value = values[key] { exposed.append(value) }
        }
        let controls = values.compactMap { key, value -> Double? in
            guard !exposedOutcomeKeys.contains(key), !eventDays.contains(key) else { return nil }
            return value
        }
        let exposedMean = mean(exposed), controlMean = mean(controls)
        let difference = exposedMean.flatMap { lhs in controlMean.map { lhs - $0 } }
        let interval = difference.flatMap { diff -> ClosedRange<Double>? in
            guard exposed.count > 1, controls.count > 1 else { return nil }
            let se = sqrt(variance(exposed) / Double(exposed.count) + variance(controls) / Double(controls.count))
            return (diff - 1.96 * se)...(diff + 1.96 * se)
        }
        return EventOutcomeResult(outcomeOffsetDays: outcomeOffsetDays, exposedCount: exposed.count, controlCount: controls.count,
                                  exposedMean: exposedMean, controlMean: controlMean, meanDifference: difference,
                                  confidenceInterval: interval, limitations: [
                                    "Multiple events on one day are collapsed into one exposure day.",
                                    "Control days exclude event and exposed outcome days.",
                                    "Scheduled and as-needed medication comparisons must use separate event metrics.",
                                    "This comparison describes association, not causation."
                                  ])
    }

    private func mean(_ values: [Double]) -> Double? { values.isEmpty ? nil : values.reduce(0, +) / Double(values.count) }
    private func variance(_ values: [Double]) -> Double {
        guard values.count > 1, let mean = mean(values) else { return 0 }
        return values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count - 1)
    }
}
