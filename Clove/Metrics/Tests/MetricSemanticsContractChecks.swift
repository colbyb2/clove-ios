import Foundation

/// App-compiled contract checks used until `AN-007` creates the analytics XCTest target.
/// The cases are deliberately pure so they can move unchanged into XCTest assertions.
enum MetricSemanticsContractChecks {
    struct Failure: Equatable {
        let name: String
        let message: String
    }

    static func failures() -> [Failure] {
        var failures: [Failure] = []

        check("valid continuous definition", failures: &failures) {
            baseDefinition().isValid
        }
        check("invalid ID", failures: &failures) {
            definition(id: "pain level").validationIssues.contains(.invalidID)
        }
        check("missing display name", failures: &failures) {
            definition(displayName: "  ").validationIssues.contains(.missingDisplayName)
        }
        check("duplicate categories", failures: &failures) {
            definition(
                measurementLevel: .categorical,
                unit: .category,
                domain: .categories(["Sunny", "sunny"]),
                aggregation: MetricAggregationPolicy(daily: .mode, weekly: .distribution, monthly: .distribution)
            ).validationIssues.contains(.invalidCategories)
        }
        check("categorical domain required", failures: &failures) {
            definition(measurementLevel: .categorical, unit: .category, domain: .unrestricted)
                .validationIssues.contains(.incompatibleDomain)
        }
        check("binary domain required", failures: &failures) {
            definition(measurementLevel: .binary, unit: .occurrence, domain: .numeric(0...10))
                .validationIssues.contains(.incompatibleDomain)
        }
        check("percentage domain required", failures: &failures) {
            definition(measurementLevel: .percentage, unit: .percentage, domain: .numeric(0...1))
                .validationIssues.contains(.incompatibleDomain)
        }
        check("continuous sum rejected", failures: &failures) {
            definition(aggregation: MetricAggregationPolicy(daily: .average, weekly: .sum, monthly: .average))
                .validationIssues.contains(.incompatibleReducer(reducer: .sum, measurementLevel: .continuous))
        }
        check("count sum accepted", failures: &failures) {
            definition(
                measurementLevel: .count,
                unit: .count,
                domain: .nonNegative,
                aggregation: MetricAggregationPolicy(daily: .sum, weekly: .sum, monthly: .sum)
            ).isValid
        }
        check("event none accepted", failures: &failures) {
            definition(
                measurementLevel: .event,
                unit: .occurrence,
                domain: .unrestricted,
                aggregation: MetricAggregationPolicy(daily: .none, weekly: .count, monthly: .count)
            ).isValid
        }
        check("favorability separate from direction", failures: &failures) {
            MetricDirectionality.lowerIsBetter.favorability(of: .increasing) == .unfavorable &&
            MetricDirectionality.higherIsBetter.favorability(of: .increasing) == .favorable &&
            MetricDirectionality.neutral.favorability(of: .decreasing) == .neutral
        }
        check("all measurement levels covered", failures: &failures) {
            MetricMeasurementLevel.allCases.count == 8
        }
        check("all reducers covered", failures: &failures) {
            MetricAggregationReducer.allCases.count == 10
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

    private static func baseDefinition() -> MetricDefinition {
        definition()
    }

    private static func definition(
        id: String = "mood",
        displayName: String = "Mood",
        measurementLevel: MetricMeasurementLevel = .continuous,
        unit: MetricUnit = .score,
        domain: MetricValueDomain = .numeric(0...10),
        aggregation: MetricAggregationPolicy = MetricAggregationPolicy(
            daily: .average,
            weekly: .average,
            monthly: .average
        )
    ) -> MetricDefinition {
        MetricDefinition(
            id: MetricID(rawValue: id),
            displayName: displayName,
            description: "Daily mood score",
            category: .coreHealth,
            source: .dailyLog(field: "mood"),
            measurementLevel: measurementLevel,
            unit: unit,
            domain: domain,
            directionality: .higherIsBetter,
            aggregation: aggregation,
            unrecordedDayPolicy: .missing,
            supportedAnalyses: [.descriptive, .trend],
            recommendedVisualizations: [.line]
        )
    }
}

#if METRIC_SEMANTICS_CHECK_MAIN
@main
struct MetricSemanticsContractCheckRunner {
    static func main() {
        MetricSemanticsContractChecks.assertAllPass()
        print("Metric semantics contract checks passed")
    }
}
#endif
