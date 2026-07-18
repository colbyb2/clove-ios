import Foundation

/// Pure catalog checks that will move into XCTest in `AN-007`.
enum MetricCatalogContractChecks {
    struct Failure: Equatable {
        let name: String
        let message: String
    }

    static func failures() -> [Failure] {
        var failures: [Failure] = []
        let definitions = MetricCatalog.staticDefinitions

        check("all static definitions valid", failures: &failures) {
            definitions.allSatisfy(\.isValid)
        }
        check("static IDs unique", failures: &failures) {
            Set(definitions.map(\.id)).count == definitions.count
        }
        check("registered static count", failures: &failures) {
            MetricCatalog.registeredStaticDefinitions.count == 11
        }
        check("hydration is daily volume", failures: &failures) {
            MetricCatalog.hydration.measurementLevel == .continuous &&
            MetricCatalog.hydration.unit == .fluidOunces &&
            MetricCatalog.hydration.aggregation.weekly == .average
        }
        check("weather is categorical", failures: &failures) {
            MetricCatalog.weather.measurementLevel == .categorical &&
            !MetricCatalog.weather.supportedAnalyses.contains(.trend)
        }
        check("bowel metrics separated", failures: &failures) {
            MetricCatalog.bristolStoolType.measurementLevel == .ordinal &&
            MetricCatalog.bowelMovementFrequency.measurementLevel == .count &&
            MetricCatalog.bristolStoolType.id != MetricCatalog.bowelMovementFrequency.id
        }
        check("pain direction is unfavorable when rising", failures: &failures) {
            MetricCatalog.painLevel.directionality.favorability(of: .increasing) == .unfavorable
        }
        check("medication adherence excludes unweighted aggregation", failures: &failures) {
            MetricCatalog.medicationAdherence.aggregation.weekly == .weightedPercentage &&
            MetricCatalog.medicationAdherence.unrecordedDayPolicy == .missing
        }
        let dynamicDefinitions = [
            MetricCatalog.symptom(id: "symptom:1", name: "Fatigue", isBinary: false),
            MetricCatalog.symptom(id: "symptom:2", name: "Rash", isBinary: true),
            MetricCatalog.medicationOccurrence(id: "medication:1", name: "Example medication"),
            MetricCatalog.activityOccurrence(id: "activity:1", name: "Walking"),
            MetricCatalog.mealOccurrence(id: "meal:1", name: "Coffee")
        ]

        check("dynamic families valid", failures: &failures) {
            dynamicDefinitions.allSatisfy(\.isValid)
        }
        check("binary symptom is not a severity scale", failures: &failures) {
            dynamicDefinitions[1].measurementLevel == .binary &&
            dynamicDefinitions[1].aggregation.weekly == .occurrenceRate
        }
        check("events do not infer absent days", failures: &failures) {
            dynamicDefinitions.suffix(3).allSatisfy { $0.unrecordedDayPolicy == .missing }
        }
        check("event families support event outcomes", failures: &failures) {
            dynamicDefinitions.suffix(3).allSatisfy { $0.supportedAnalyses.contains(.eventOutcome) }
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

#if METRIC_CATALOG_CHECK_MAIN
@main
struct MetricCatalogContractCheckRunner {
    static func main() {
        MetricSemanticsContractChecks.assertAllPass()
        MetricCatalogContractChecks.assertAllPass()
        print("Metric semantics and catalog contract checks passed")
    }
}
#endif
