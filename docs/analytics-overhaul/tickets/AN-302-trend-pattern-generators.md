# AN-302 — Trend and pattern generators

- Status: done
- Phase: 4 — Insights and dashboard
- Dependencies: AN-101, AN-301

## Objective

Generate tested insights for meaningful changes, streaks, volatility, weekday patterns, achievements, and warnings.

## Scope

- Time-aware robust trends, personal-baseline changes, repeated weekday patterns, streaks respecting missingness, and data-quality thresholds.
- Replace hard-coded confidence and three-point monotonic warnings.

## Acceptance criteria

- Patterns require repeated observations per group.
- Trend magnitude is expressed in metric units and health favorability is separate.
- Sparse results use “early signal” or remain hidden.
- Pure-noise fixtures do not routinely emit insights.

## Verification

- Positive, negative, sparse, outlier, and noise fixtures.
- Clove scheme build.

## Completion notes

Implemented equal-period change, median-pairwise robust trend, repeated-weekday, recording-streak, and median-absolute-deviation volatility generators. Thresholds use definition sample policies, coverage, robust spread, and explicit early-signal quality. Added positive, sparse, repeated-group, volatility, missingness, and noise fixtures. Verified by the full analytics suite and Clove device build on 2026-07-18.
