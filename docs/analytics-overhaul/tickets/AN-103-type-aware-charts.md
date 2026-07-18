# AN-103 — Type-aware visualizations

- Status: done
- Phase: 2 — Unified charts and metric details
- Dependencies: AN-102

## Objective

Render each metric using a visualization appropriate to its semantics.

## Scope

- Continuous/ordinal trends, binary occurrence/rate, count bars, categorical distributions, event overlays, hydration goal progress, and bowel frequency/Bristol distributions.
- Raw versus rolling summary where supported.
- Honest aggregation and smoothing labels.

## Acceptance criteria

- Categorical metrics are not rendered as continuous lines.
- Binary aggregated values use the correct rate domain and denominator.
- Missing continuous observations create visible gaps.
- Bowel frequency and stool type are separate views.
- Charts do not overshoot valid domains through interpolation.

## Verification

- Snapshot or visual regression fixtures for each chart family.
- Accessibility labels for chart summaries.
- Clove scheme build.

## Completion notes

- Added semantic chart families for numeric/ordinal lines, counts, binary and weighted rates, categorical distributions, event occurrences, hydration goal progress, and Bristol distributions.
- Binary buckets retain their observed denominator and use a 0–100 rate domain; categorical values never pass through a continuous line chart.
- Bowel frequency remains a count metric while Bristol stool type is rendered as a separate distribution.
- Added labeled daily versus seven-day display modes where supported. Charts use linear interpolation and catalog domains so smoothing cannot overshoot valid values.
- Added deterministic chart-family, missing-gap, denominator, hydration, and Bristol fixtures.
