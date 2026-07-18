# AN-005 — Data revisions and cache invalidation

- Status: done
- Phase: 1 — Trustworthy foundation
- Dependencies: AN-004

## Objective

Replace disconnected time-based analytics caches with a shared data revision and correctly keyed cache.

## User outcome

Insights update immediately after editing or auto-saving any relevant record.

## Scope

- Introduce a revision source incremented by log, food, activity, bowel, cycle, medication, import, and relevant settings writes.
- Key cached results by metric ID, exact range, granularity, policy version, and revision.
- Make cache coordination actor-isolated and cancellation-aware.
- Bridge legacy invalidation during migration.

## Non-goals

- Persist calculated insights across launches.
- Add telemetry.

## Acceptance criteria

- Every analytics-affecting write invalidates subsequent reads.
- Unrelated presentation settings do not invalidate data calculations.
- Editing and deleting invalidate as reliably as adding.
- Concurrent identical requests share safe work where practical.
- Stale session-cache behavior is eliminated from the new pipeline.

## Verification

- Repository-write invalidation matrix.
- Concurrent access tests.
- Clove scheme build.

## Completion notes

- Added a thread-safe shared analytics revision source with explicit reasons for every analytics-affecting write family and data import.
- Repository writes increment the revision only after successful saves, updates, or deletes. Analytically relevant settings use a focused fingerprint; presentation settings such as auto-save do not invalidate results.
- Added an actor-isolated repository cache keyed by exact metric IDs, half-open range, raw-event option, granularity, policy version, and revision. Concurrent identical requests share one load and cancellation is honored.
- Revision changes prune stale entries and bridge invalidation into the legacy loaders during the incremental migration.
- Added XCTest coverage for the write matrix, exact-key boundaries, revision invalidation, concurrency, and cancellation.
