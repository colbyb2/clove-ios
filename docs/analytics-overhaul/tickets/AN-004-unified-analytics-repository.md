# AN-004 — Unified date-range analytics repository

- Status: done
- Phase: 1 — Trustworthy foundation
- Dependencies: AN-003

## Objective

Provide one repository API for loading metric definitions, canonical observations, and raw events over explicit date ranges.

## User outcome

Every analytics screen uses the same records and respects the exact selected date range.

## Scope

- Define an injectable `AnalyticsRepository` protocol.
- Support explicit `DateInterval` queries rather than global `TimePeriod` state.
- Batch related database reads.
- Add date-bounded GRDB repository methods where absent.
- Return observations, raw events, and coverage metadata.
- Add compatibility adapters for current providers.

## Non-goals

- Precomputed rollup tables.
- UI migration.
- Statistical analysis.

## Acceptance criteria

- No repository method requires `TimePeriodManager.shared`.
- Custom ranges and historical ranges not ending today work.
- Dashboard-sized multi-metric requests avoid one full database scan per metric.
- Results are deterministic and sorted.
- Errors are surfaced rather than converted to empty data.

## Verification

- Range-boundary and batch-query tests.
- Query-count or instrumentation test for representative dashboard loads.
- Clove scheme build.

## Completion notes

- Added injectable `AnalyticsRepository` and `AnalyticsSourceLoading` contracts using explicit, half-open `DateInterval` requests.
- Added a GRDB source loader that batches five range-bound event/log tables and four identity/definition tables inside one database read. Its nine statements are fixed per request rather than multiplied by metric count.
- Repository results include sorted definitions, canonical daily observations, optional raw events, per-metric coverage states, and query diagnostics. Invalid ranges, unknown metric IDs, and source errors are thrown.
- Dynamic definitions include tracked and historical symptoms/medications plus durable meal/activity identities. Legacy name-derived IDs are retained only as compatibility aliases.
- Added a temporary provider-to-observation compatibility bridge and fixtures for historical custom ranges, half-open boundaries, deterministic sorting, fixed query cost, and error propagation.
- Verified with a code-signing-disabled Clove device build on 2026-07-18.
