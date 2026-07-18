# Analytics Methods Guide

Analysis is selected from `MetricDefinition`, never from a chart’s appearance.

- Descriptive summaries preserve numeric, count, binary, categorical, percentage, and event semantics.
- Trends require the catalog minimum sample size and use robust slopes where applicable.
- Period comparisons use equal, non-overlapping calendar-day intervals and show coverage for both periods.
- Relationships select Pearson, Spearman, point-biserial, phi, Cramér’s V, or correlation ratio from measurement levels. Missing days are not converted to zero.
- Lag scans and event windows are exploratory and disclose direction, matched groups, and limitations.
- Automatic discovery applies eligibility, coverage and effect gates, a 60-test budget, and Benjamini–Hochberg false-discovery-rate correction before ranking.
- Cycle phases exist only between explicit plausible cycle starts. Flare analysis uses explicitly logged flare state.
- Personal baselines use a 120-day window, at least 28 historical plus 7 recent observations, a recency-weighted median, and a robust deviation band.

Every result is observational. Association does not establish causation, and no analysis diagnoses a condition or recommends treatment changes.
