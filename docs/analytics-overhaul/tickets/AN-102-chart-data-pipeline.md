# AN-102 — Unified chart pipeline

- Status: done
- Phase: 2 — Unified charts and metric details
- Dependencies: AN-101

## Objective

Move Metric Explorer chart loading, range selection, aggregation, and summaries onto the unified analytics repository.

## Scope

- Introduce a single chart view model/result pipeline.
- Preserve missing-data gaps and exact ranges.
- Replace duplicate statistics in current chart views.
- Retain adapters only where an unmigrated screen still requires them.

## Acceptance criteria

- Metric Explorer no longer reads directly through `OptimizedDataLoader`.
- Custom and previous ranges use identical semantics.
- Aggregation does not change value domains unexpectedly.
- Loading, empty, error, sparse, and cancellation states are represented.

## Verification

- Pipeline tests plus representative UI smoke tests.
- Clove scheme build.

## Completion notes

- Added one `AnalyticsChartPipeline` result used by the visible Metric Explorer detail experience for range selection, calendar-safe aggregation, charts, summaries, and optional previous-period data.
- Metric selection no longer triggers legacy provider chart loading; the detail view reads through the revision-keyed analytics repository and cancels superseded requests.
- Daily missing observations split line segments, and loading, empty, sparse, failure, and cancellation states are represented without changing a metric's domain.
- Legacy chart adapters remain only for unmigrated dashboard, correlation, and debug surfaces scheduled for later phases.
