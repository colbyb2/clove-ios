import Foundation

/// Pure canonical-observation fixtures. These are executable from the command line and are
/// intended to move unchanged into the analytics XCTest target in AN-007.
enum MetricObservationContractChecks {
    struct Failure: Equatable {
        let name: String
        let message: String
    }

    static func failures() -> [Failure] {
        var failures: [Failure] = []
        let utc = TimeZone(secondsFromGMT: 0)!
        let normalizer = MetricDayNormalizer(timeZone: utc)
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let day = normalizer.day(containing: timestamp)
        let source = MetricSourceReference(kind: .dailyLog, recordID: "42", field: "mood")

        let missing = MetricObservation(
            metricID: MetricCatalog.mood.id,
            timestamp: timestamp,
            day: day,
            state: .missing,
            source: source
        )
        let zero = MetricObservation(
            metricID: MetricCatalog.mood.id,
            timestamp: timestamp,
            day: day,
            state: .observed(.number(0)),
            source: source
        )
        let explicitNone = MetricObservation(
            metricID: MetricCatalog.mood.id,
            timestamp: timestamp,
            day: day,
            state: .explicitNone,
            source: source
        )
        check("missing, zero, and explicit none differ", failures: &failures) {
            missing.state != zero.state && missing.state != explicitNone.state && zero.state != explicitNone.state
        }

        var bowelBatch = MetricObservationBatch.empty
        for index in 0..<2 {
            let eventDate = timestamp.addingTimeInterval(Double(index * 900))
            let eventSource = MetricSourceReference(kind: .bowelMovement, recordID: String(index + 1))
            bowelBatch.observations.append(MetricObservation(
                metricID: MetricCatalog.bowelMovementFrequency.id,
                timestamp: eventDate,
                day: day,
                state: .observed(.number(1)),
                source: eventSource
            ))
            bowelBatch.rawEvents.append(MetricRawEvent(
                metricID: MetricCatalog.bowelMovementFrequency.id,
                timestamp: eventDate,
                day: day,
                source: eventSource,
                attributes: ["bristolType": .number(Double(index + 3))]
            ))
        }
        let reducedBowel = MetricDailyReducer(normalizer: normalizer).reduce(
            bowelBatch,
            definitions: [MetricCatalog.bowelMovementFrequency]
        )
        check("duplicates reduce without losing raw events", failures: &failures) {
            reducedBowel.observations.count == 1 &&
            reducedBowel.observations.first?.state == .observed(.number(2)) &&
            reducedBowel.rawEvents == bowelBatch.rawEvents
        }
        check("frequency remains distinct from Bristol type", failures: &failures) {
            MetricCatalog.bowelMovementFrequency.id != MetricCatalog.bristolStoolType.id &&
            !reducedBowel.observations.contains { $0.metricID == MetricCatalog.bristolStoolType.id }
        }

        let edited = MetricObservation(
            metricID: MetricCatalog.mood.id,
            timestamp: timestamp.addingTimeInterval(60),
            day: day,
            state: .observed(.number(8)),
            source: source
        )
        check("identity is stable after an edit", failures: &failures) {
            edited.id == zero.id
        }

        check("DST spring transition has two distinct local days", failures: &failures) {
            let zone = TimeZone(identifier: "America/New_York")!
            let dstNormalizer = MetricDayNormalizer(timeZone: zone)
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            let before = calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23, minute: 30))!
            let after = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 3, minute: 30))!
            return dstNormalizer.dayKey(for: before) != dstNormalizer.dayKey(for: after) &&
                calendar.dateComponents([.day], from: dstNormalizer.day(containing: before), to: dstNormalizer.day(containing: after)).day == 1
        }

        check("timezone is an explicit part of day identity", failures: &failures) {
            let newYork = MetricDayNormalizer(timeZone: TimeZone(identifier: "America/New_York")!)
            let tokyo = MetricDayNormalizer(timeZone: TimeZone(identifier: "Asia/Tokyo")!)
            return newYork.dayKey(for: timestamp) != tokyo.dayKey(for: timestamp)
        }

        let latestSource = MetricSourceReference(kind: .dailyLog, recordID: "43", field: "mood")
        let latest = MetricObservation(
            metricID: MetricCatalog.mood.id,
            timestamp: timestamp.addingTimeInterval(120),
            day: day,
            state: .observed(.number(9)),
            source: latestSource
        )
        let reductionA = MetricDailyReducer(normalizer: normalizer).reduce(
            MetricObservationBatch(observations: [latest, zero], rawEvents: []),
            definitions: [MetricCatalog.mood]
        )
        let reductionB = MetricDailyReducer(normalizer: normalizer).reduce(
            MetricObservationBatch(observations: [zero, latest], rawEvents: []),
            definitions: [MetricCatalog.mood]
        )
        check("daily reduction is input-order independent", failures: &failures) {
            reductionA == reductionB && reductionA.observations.first?.state == .observed(.number(9))
        }

        return failures
    }

    static func assertAllPass(file: StaticString = #fileID, line: UInt = #line) {
        let messages = failures().map { "\($0.name): \($0.message)" }
        precondition(messages.isEmpty, messages.joined(separator: "\n"), file: file, line: line)
    }

    private static func check(
        _ name: String,
        failures: inout [Failure],
        condition: () -> Bool
    ) {
        if !condition() {
            failures.append(Failure(name: name, message: "Expected condition to be true"))
        }
    }
}

#if METRIC_OBSERVATION_CHECK_MAIN
@main
struct MetricObservationContractCheckRunner {
    static func main() {
        MetricSemanticsContractChecks.assertAllPass()
        MetricCatalogContractChecks.assertAllPass()
        MetricObservationContractChecks.assertAllPass()
        print("Metric semantics, catalog, and observation contract checks passed")
    }
}
#endif
