# Analytics Troubleshooting

## An expected metric is missing

Confirm its catalog definition and source adapter exist, its stable ID resolves, the selected half-open range contains source records, and its unrecorded-day policy is correct. Check `MetricCatalogCompatibilityChecks` for provider-browser mapping.

## A chart is empty

Inspect `MetricCoverage` and observation states. Missing is intentionally not zero. Categorical/Bristol metrics use distributions, events use occurrences, and long ranges aggregate weekly or monthly.

## No discovery appears

This can be correct. Verify minimum samples, at least 40% coverage, matching recorded days, effect threshold, adjusted q-value, and the 60-test budget. Never bypass correction to force a card.

## Insights appear stale

Every analytics-affecting repository write must bump `AnalyticsRevisionSource`. Confirm the cache key changes and that presentation-only settings do not bump it.

## Database update failed

The recovery screen preserves source records and offers Retry Update. GRDB migrations are transactional and idempotent. Diagnostics store only a generic migration outcome, never the database error text or health values.

## Performance regressed

Run `Phase6ProductionReadinessTests`, confirm the repository remains one read/nine statements, look for filtering the entire observation array per metric, and profile a ten-year history using the budgets in `PERFORMANCE.md`.
