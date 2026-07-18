# AN-403 — Personalized baselines

- Status: done
- Phase: 5 — Advanced discovery
- Dependencies: AN-101, AN-302

## Objective

Compare recent values to each user's established history instead of universal thresholds alone.

## Scope

- Baseline windows, minimum history, recency weighting, robust location/variation, reset behavior, and explainable deviation bands.

## Acceptance criteria

- Baselines do not activate before minimum coverage is met.
- Outliers do not dominate the baseline.
- Users can see the baseline period and meaning.
- Tracking gaps and major definition changes invalidate or qualify baselines.

## Verification

- Stable, shifted, sparse, outlier, and long-gap fixtures.
- Clove scheme build.

## Completion notes

Implemented a 120-day recency-weighted median baseline with a robust median-absolute-deviation band, 28 historical plus 7 recent observation minimum, visible source period, definition-change filtering, and long-gap qualification. Stable, shifted, sparse, outlier, gap, and definition-change tests pass.
