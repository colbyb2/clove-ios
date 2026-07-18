# AN-201 — Pair alignment and coverage

- Status: done
- Phase: 3 — Relationship engine
- Dependencies: Phase 2 exit gate

## Objective

Build a tested alignment layer for two metrics that preserves missingness, eligibility, daily reducers, and coverage.

## Scope

- Same-day alignment, explicit lag parameter, matching-day coverage, exclusions, and quality flags.
- Efficient date-keyed alignment instead of repeated linear searches.

## Acceptance criteria

- Missing never becomes zero during alignment.
- Duplicate-day handling follows metric definitions.
- Result reports eligible, observed, matched, and excluded counts.
- Alignment is deterministic and timezone-safe.

## Verification

- Sparse, duplicate, event, and DST fixtures.
- Clove scheme build.

## Completion notes

Implemented date-keyed, timezone-safe same-day and lag alignment with explicit coverage, exclusions, quality flags, and missing-value preservation. Sparse, lag, and DST regressions pass.
