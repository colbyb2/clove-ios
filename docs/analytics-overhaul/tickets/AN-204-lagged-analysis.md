# AN-204 — Lagged relationships

- Status: done
- Phase: 3 — Relationship engine
- Dependencies: AN-201, AN-202, AN-203

## Objective

Analyze whether one metric tends to precede another from seven days before through seven days after.

## Scope

- Configurable lag alignment, lag profile, best-supported lag, multiple-lag correction, and direction explanations.

## Acceptance criteria

- Lag direction is unambiguous in API and UI copy.
- Same-day and delayed results share evidence rules.
- Searching multiple lags cannot report uncorrected significance as definitive.
- Sparse lags are omitted or labeled insufficient.

## Verification

- Synthetic fixtures with known lagged signals and pure noise.
- Clove scheme build.

## Completion notes

Implemented −7 through +7 day profiles, unambiguous factor-before-outcome semantics, per-lag evidence rules, insufficient-lag omission, strongest-supported lag, and an exploratory multiple-search warning.
