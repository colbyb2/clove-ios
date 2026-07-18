# AN-104 — Rich metric detail screen

- Status: done
- Phase: 2 — Unified charts and metric details
- Dependencies: AN-101, AN-103

## Objective

Create a reusable metric detail experience with type-specific summaries and drill-down.

## Scope

- Current value versus baseline, trend, distribution/frequency, coverage, notable dates, related-analysis entry point, and daily-log navigation.
- Metric-family modules for symptoms, hydration, medication, activities, meals, bowel movements, and cycle flow.

## Acceptance criteria

- Every registered metric has a useful detail layout.
- Users can see how many observations support each summary.
- Notable dates navigate to the correct daily record.
- Unsupported modules are omitted rather than displaying meaningless values.

## Verification

- UI tests for representative metric families and data states.
- Dynamic Type and VoiceOver review.
- Clove scheme build.

## Completion notes

- Added reusable repository-backed metric details with type-specific headline values, trend, chart, comparison, coverage, limitations, notable dates, and a relationship-analysis entry point.
- Every provider-resolvable registered metric uses the same semantic definition and omits unsupported trend or distribution modules.
- Observation and day counts are shown alongside summaries. Notable dates open the matching daily-record detail, including event-only days without an existing `DailyLog` row.
- Layout uses adaptive summary cards and scalable system text for Dynamic Type.
