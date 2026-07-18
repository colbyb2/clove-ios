import XCTest
@testable import Clove

final class InsightEvidenceModelTests: XCTestCase {
    func testConfidenceComesFromEvidenceAndIdentityIsStable() throws {
        let dataset = insightDataset(definitions: [MetricCatalog.hydration], dayCount: 14, values: [
            MetricCatalog.hydration.id: (1...14).map { ($0, .number(Double($0 * 4))) }
        ])
        let first = try XCTUnwrap(InsightGenerator().generate(dataset: dataset, generatedAt: AnalyticsTestDates.date(2026, 8, 1)).first { $0.presentationHint == .change })
        let second = try XCTUnwrap(InsightGenerator().generate(dataset: dataset, generatedAt: AnalyticsTestDates.date(2026, 8, 2)).first { $0.presentationHint == .change })

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.confidence, 0.7, accuracy: 1e-9)
        XCTAssertTrue(try XCTUnwrap(first.evidence).whyText.contains("14 recorded observations"))
        XCTAssertEqual(Set(InsightGenerator().generate(dataset: dataset).map(\.id)).count, InsightGenerator().generate(dataset: dataset).count)
    }

    func testCopyPolicyRejectsMedicalAndCausalClaims() {
        XCTAssertFalse(InsightCopyPolicy.isAllowed("Hydration causes lower pain"))
        XCTAssertFalse(InsightCopyPolicy.isAllowed("This diagnoses a condition"))
        XCTAssertFalse(InsightCopyPolicy.isAllowed("This will improve your health"))
        XCTAssertTrue(InsightCopyPolicy.isAllowed("Recorded pain was lower in this period"))
    }
}

final class InsightGeneratorTests: XCTestCase {
    func testRobustTrendUsesMetricUnitsAndFavorability() throws {
        let dataset = insightDataset(definitions: [MetricCatalog.painLevel], dayCount: 21, values: [
            MetricCatalog.painLevel.id: (1...21).map { ($0, .number(Double($0) / 4)) }
        ])
        let insight = try XCTUnwrap(InsightGenerator().generate(dataset: dataset).first { $0.evidence?.provenance.generator == "robust-trend" })
        XCTAssertEqual(insight.type, .warning)
        XCTAssertTrue(insight.description.contains("points"))
        XCTAssertGreaterThan(try XCTUnwrap(insight.evidence?.effect), 0)
    }

    func testSparseTrendStaysHiddenAndMissingBreaksStreak() {
        let sparse = insightDataset(definitions: [MetricCatalog.energyLevel], dayCount: 30, values: [
            MetricCatalog.energyLevel.id: [(1, .number(1)), (8, .number(3)), (16, .number(5)), (25, .number(7))]
        ])
        XCTAssertFalse(InsightGenerator().generate(dataset: sparse).contains { $0.evidence?.provenance.generator == "robust-trend" })
        XCTAssertFalse(InsightGenerator().generate(dataset: sparse).contains { $0.presentationHint == .streak })
    }

    func testWeekdayPatternRequiresRepeatedGroups() {
        let start = AnalyticsTestDates.date(2026, 6, 1)
        let calendar = AnalyticsTestDates.calendar
        let values = (1...28).map { day -> (Int, MetricObservedValue) in
            let date = calendar.date(byAdding: .day, value: day - 1, to: start)!
            let isMonday = calendar.component(.weekday, from: date) == 2
            return (day, .number(isMonday ? 9 : 2))
        }
        let rich = insightDataset(definitions: [MetricCatalog.energyLevel], dayCount: 28, start: start, values: [MetricCatalog.energyLevel.id: values])
        XCTAssertTrue(InsightGenerator().generate(dataset: rich).contains { $0.presentationHint == .weekday })

        let sparse = insightDataset(definitions: [MetricCatalog.energyLevel], dayCount: 10, start: start, values: [MetricCatalog.energyLevel.id: Array(values.prefix(10))])
        XCTAssertFalse(InsightGenerator().generate(dataset: sparse).contains { $0.presentationHint == .weekday })
    }

    func testVolatilityChangeIsRobustAndNoiseDoesNotEmitTrend() {
        let stable = [4.9, 5.0, 5.1, 5.0, 4.9, 5.1, 5.0]
        let variable = [1.0, 9.0, 2.0, 8.0, 3.0, 7.0, 5.0]
        let volatility = insightDataset(definitions: [MetricCatalog.mood], dayCount: 14, values: [
            MetricCatalog.mood.id: (stable + variable).enumerated().map { ($0.offset + 1, .number($0.element)) }
        ])
        XCTAssertTrue(InsightGenerator().generate(dataset: volatility).contains { $0.presentationHint == .volatility })

        let noise = insightDataset(definitions: [MetricCatalog.mood], dayCount: 21, values: [
            MetricCatalog.mood.id: (1...21).map { ($0, .number([4.8, 5.2, 5.0][$0 % 3])) }
        ])
        XCTAssertFalse(InsightGenerator().generate(dataset: noise).contains { $0.evidence?.provenance.generator == "robust-trend" })
    }
}

final class WellbeingSnapshotTests: XCTestCase {
    func testSnapshotUsesRealPriorValuesAndEqualAvailableWeights() throws {
        let symptom = MetricCatalog.symptom(id: "symptom:fatigue", name: "Fatigue", isBinary: false)
        let binarySymptom = MetricCatalog.symptom(id: "symptom:nausea", name: "Nausea", isBinary: true)
        let definitions = [MetricCatalog.mood, MetricCatalog.painLevel, symptom, binarySymptom]
        let current = insightDataset(definitions: definitions, dayCount: 10, values: [
            MetricCatalog.mood.id: (1...10).map { ($0, .number(8)) },
            MetricCatalog.painLevel.id: (1...10).map { ($0, .number(3)) },
            symptom.id: (1...10).map { ($0, .number(4)) },
            binarySymptom.id: (1...10).map { ($0, .boolean(true)) }
        ])
        let previous = insightDataset(definitions: definitions, dayCount: 10, start: AnalyticsTestDates.date(2026, 5, 1), values: [
            MetricCatalog.mood.id: (1...10).map { ($0, .number(6)) },
            MetricCatalog.painLevel.id: (1...10).map { ($0, .number(5)) },
            symptom.id: (1...10).map { ($0, .number(5)) },
            binarySymptom.id: (1...10).map { ($0, .boolean(false)) }
        ])
        let snapshot = WellbeingSnapshotEngine().build(current: current, previous: previous)

        XCTAssertEqual(snapshot.availableComponents.count, 3)
        XCTAssertTrue(snapshot.availableComponents.allSatisfy { abs($0.weight - 1.0 / 3.0) < 1e-9 })
        XCTAssertEqual(snapshot.components.first { $0.kind == .mood }?.change, 2)
        XCTAssertEqual(snapshot.components.first { $0.kind == .pain }?.favorability, .favorable)
        XCTAssertEqual(snapshot.components.first { $0.kind == .energy }?.weight, 0)
        XCTAssertNil(snapshot.components.first { $0.kind == .energy }?.currentValue)
        XCTAssertEqual(snapshot.components.filter { $0.kind == .symptoms }.count, 1)
        XCTAssertEqual(snapshot.components.first { $0.kind == .symptoms }?.metricIDs.count, 2)
        XCTAssertEqual(snapshot.components.first { $0.kind == .symptoms }?.currentValue, 7)
    }
}

private func insightDataset(definitions: [MetricDefinition], dayCount: Int,
                            start: Date = AnalyticsTestDates.date(2026, 7, 1),
                            values: [MetricID: [(Int, MetricObservedValue)]]) -> AnalyticsDataset {
    let calendar = AnalyticsTestDates.calendar
    let end = calendar.date(byAdding: .day, value: dayCount, to: start)!
    let interval = DateInterval(start: start, end: end)
    var observations: [MetricObservation] = []
    for definition in definitions {
        for (index, value) in values[definition.id] ?? [] {
            let date = calendar.date(byAdding: .day, value: index - 1, to: start)!
            observations.append(MetricObservation(metricID: definition.id, timestamp: date, day: date,
                state: .observed(value), source: MetricSourceReference(kind: .dailyLog, recordID: "\(definition.id.rawValue)-\(index)")))
        }
    }
    let coverage = Dictionary(uniqueKeysWithValues: definitions.map { definition in
        let matching = observations.filter { $0.metricID == definition.id }
        return (definition.id, MetricCoverage(metricID: definition.id, interval: interval,
            possibleDayCount: dayCount, sourceDayCount: Set(matching.map { calendar.startOfDay(for: $0.day) }).count,
            observedCount: matching.count, missingCount: dayCount - matching.count, explicitNoneCount: 0,
            notApplicableCount: 0, firstObservation: matching.map(\.timestamp).min(), lastObservation: matching.map(\.timestamp).max()))
    })
    return AnalyticsDataset(interval: interval, definitions: definitions, observations: observations,
        rawEvents: [], coverage: coverage, metricAliases: [:],
        diagnostics: AnalyticsQueryDiagnostics(databaseReadCount: 0, statementCount: 0))
}
