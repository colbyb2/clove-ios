# AN-001 — Metric semantics contract

- Status: done
- Phase: 1 — Trustworthy foundation
- Dependencies: none

## Objective

Introduce UI-independent contracts describing what a metric means and how it may be aggregated, compared, and presented.

## User outcome

Future charts and insights interpret each health metric consistently instead of applying generic rules that can be misleading.

## Scope

- Define stable `MetricID` and `MetricDefinition` types.
- Define measurement level, unit, directionality, valid domain, reducers, absence policy, and analysis capabilities.
- Define chart recommendation metadata without importing SwiftUI into the core analytics contract.
- Provide compatibility mapping from existing `MetricDataType` and `MetricProvider` values.
- Document naming and extension rules for future metrics.

## Non-goals

- Migrate providers or screens.
- Change database tables.
- Implement statistical calculations.

## Acceptance criteria

- Contracts compile without SwiftUI dependencies.
- Direction of numeric change is distinct from whether the change is favorable.
- Count, event, ordinal, binary, categorical, continuous, and percentage semantics are representable.
- Missing, explicit-none, and not-applicable policies can be declared.
- Invalid reducer/measurement combinations are prevented or validated.
- Existing metrics can be represented without changing current UI behavior.

## Verification

- Compiled contract checks for valid and invalid definitions; `AN-007` will move these cases into the repository's first XCTest target.
- Compile-time or test coverage for every enum case.
- Clove scheme build.

## Completion notes

Completed 2026-07-18.

- Added the Foundation-only `MetricSemantics` contracts for stable identity, measurement level, unit, domain, directionality, aggregation, absence policy, analysis support, sample requirements, visualization recommendations, and display format.
- Added deterministic validation for identifiers, required text, categorical/binary/percentage domains, sample requirements, display metadata, and reducer compatibility.
- Added legacy mappings for every `MetricDataType`, `MetricCategory`, and `MetricChartType`, plus a compatibility definition for every existing `MetricProvider`.
- Added compiled contract checks covering valid and invalid definitions and change favorability. Debug registry initialization asserts these checks while `AN-007` owns creation of the XCTest target.
- Documented stable ID naming and metric extension rules in `DATA_SEMANTICS.md` and recorded the test-harness boundary in `AD-004`.
- Verification passed: standalone contract executable, `git diff --check`, and generic iOS Clove build with code signing disabled.
