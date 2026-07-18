# AN-203 — Inference and confidence intervals

- Status: done
- Phase: 3 — Relationship engine
- Dependencies: AN-202

## Objective

Replace threshold p-value approximations and hard-coded confidence with defensible uncertainty estimates.

## Scope

- Proper p-values where applicable, confidence intervals, effect-size interpretation, minimum sample policies, and outlier sensitivity.
- Evidence-quality labels based on coverage and method limitations.

## Acceptance criteria

- P-values are not bucketed constants.
- Confidence is not equated with absolute correlation.
- Minimum samples are stricter than the current three-day rule and metric-aware.
- Result models disclose assumptions and limitations.

## Verification

- Cross-check against published/reference statistical outputs.
- Numerical stability tests.
- Clove scheme build.

## Completion notes

Implemented continuous two-sided p-values, Fisher and deterministic bootstrap intervals, stricter metric-aware minimum samples, coverage-based evidence quality, and outlier-sensitivity disclosure.
