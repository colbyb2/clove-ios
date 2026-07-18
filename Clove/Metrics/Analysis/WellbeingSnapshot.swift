import Foundation

enum WellbeingComponentKind: String, CaseIterable, Sendable {
    case mood = "Mood"
    case pain = "Pain"
    case energy = "Energy"
    case symptoms = "Symptoms"
    case adherence = "Medication adherence"
}

struct WellbeingSnapshotComponent: Identifiable, Equatable, Sendable {
    var id: String { kind.rawValue }
    let kind: WellbeingComponentKind
    let metricIDs: [MetricID]
    let currentValue: Double?
    let previousValue: Double?
    let change: Double?
    let unitLabel: String
    let favorability: MetricChangeFavorability
    let observedDayCount: Int
    let possibleDayCount: Int
    let weight: Double

    var coverage: Double { possibleDayCount > 0 ? Double(observedDayCount) / Double(possibleDayCount) : 0 }
}

struct WellbeingSnapshot: Equatable, Sendable {
    let interval: DateInterval
    let previousInterval: DateInterval?
    let components: [WellbeingSnapshotComponent]
    let limitations: [String]

    var availableComponents: [WellbeingSnapshotComponent] { components.filter { $0.currentValue != nil } }
}

struct WellbeingSnapshotEngine {
    func build(current: AnalyticsDataset, previous: AnalyticsDataset?) -> WellbeingSnapshot {
        var components: [WellbeingSnapshotComponent] = []
        components.append(component(kind: .mood, ids: [MetricCatalog.mood.id], current: current, previous: previous))
        components.append(component(kind: .pain, ids: [MetricCatalog.painLevel.id], current: current, previous: previous))
        components.append(component(kind: .energy, ids: [MetricCatalog.energyLevel.id], current: current, previous: previous))
        components.append(component(kind: .adherence, ids: [MetricCatalog.medicationAdherence.id], current: current, previous: previous))
        let symptomIDs = current.definitions.filter { $0.category == .symptoms }.map(\.id).sorted { $0.rawValue < $1.rawValue }
        components.append(component(kind: .symptoms, ids: symptomIDs, current: current, previous: previous))
        let availableCount = max(1, components.filter { $0.currentValue != nil }.count)
        components = components.map { value in
            WellbeingSnapshotComponent(kind: value.kind, metricIDs: value.metricIDs, currentValue: value.currentValue,
                previousValue: value.previousValue, change: value.change, unitLabel: value.unitLabel,
                favorability: value.favorability, observedDayCount: value.observedDayCount,
                possibleDayCount: value.possibleDayCount, weight: value.currentValue == nil ? 0 : 1 / Double(availableCount))
        }
        var limitations = ["This snapshot summarizes your recorded data and is not medical advice.",
                           "Missing components are shown as unavailable and are not treated as poor scores."]
        if components.contains(where: { $0.currentValue != nil && $0.coverage < 0.5 }) {
            limitations.append("Some components have data on fewer than half of eligible days.")
        }
        return WellbeingSnapshot(interval: current.interval, previousInterval: previous?.interval,
                                 components: components, limitations: limitations)
    }

    private func component(kind: WellbeingComponentKind, ids: [MetricID], current: AnalyticsDataset,
                           previous: AnalyticsDataset?) -> WellbeingSnapshotComponent {
        let currentValues = ids.compactMap { scalar(id: $0, kind: kind, dataset: current) }
        let previousValues = previous.map { data in ids.compactMap { scalar(id: $0, kind: kind, dataset: data) } } ?? []
        let currentValue = mean(currentValues)
        let previousValue = mean(previousValues)
        let change = currentValue.flatMap { current in previousValue.map { current - $0 } }
        let directionality: MetricDirectionality = switch kind {
        case .mood, .energy, .adherence: .higherIsBetter
        case .pain, .symptoms: .lowerIsBetter
        }
        let direction: MetricChangeDirection = change.map { abs($0) < 0.000_001 ? .stable : ($0 > 0 ? .increasing : .decreasing) } ?? .stable
        let coverages = ids.compactMap { current.coverage[$0] }
        return WellbeingSnapshotComponent(kind: kind, metricIDs: ids, currentValue: currentValue,
            previousValue: previousValue, change: change, unitLabel: kind == .adherence ? "%" : "points",
            favorability: directionality.favorability(of: direction),
            observedDayCount: coverages.map(\.sourceDayCount).max() ?? 0,
            possibleDayCount: coverages.map(\.possibleDayCount).max() ?? dayCount(current.interval), weight: 0)
    }

    private func scalar(id: MetricID, kind: WellbeingComponentKind, dataset: AnalyticsDataset) -> Double? {
        guard let definition = dataset.definitions.first(where: { $0.id == id }) else { return nil }
        guard let value = MetricAnalysisSummaryEngine().summarize(definition: definition, dataset: dataset).value?.comparisonScalar else { return nil }
        // Binary symptoms summarize as a 0...100 occurrence rate. Convert them to the
        // snapshot's shared 0...10 symptom-burden scale before combining with ratings.
        if kind == .symptoms, definition.measurementLevel == .binary { return value / 10 }
        return value
    }

    private func mean(_ values: [Double]) -> Double? { values.isEmpty ? nil : values.reduce(0, +) / Double(values.count) }
    private func dayCount(_ interval: DateInterval) -> Int { max(1, Calendar.current.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1) }
}
