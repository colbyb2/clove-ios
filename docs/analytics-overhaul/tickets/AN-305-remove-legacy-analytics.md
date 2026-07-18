# AN-305 — Retire legacy analytics stack

- Status: done
- Phase: 4 — Insights and dashboard
- Dependencies: AN-303, AN-304

## Objective

Remove the fixed `MetricType` analytics path after all production consumers use the unified pipeline.

## Scope

- Migrate dashboard widgets and smart insights.
- Remove or reduce `ChartDataManager`, legacy aggregation/statistics, compatibility code, and duplicate models.
- Update `docs/adding-metrics.md` to the shipped architecture.

## Acceptance criteria

- No production analytics screen depends on `ChartDataManager` or fixed `MetricType` data loading.
- Dynamic metrics participate wherever their definitions permit.
- Duplicate cache and statistics implementations are removed.
- There is one documented way to add a metric.

## Verification

- Repository search for legacy consumers.
- Full analytics tests and Clove scheme build.

## Completion notes

Migrated Insights, smart insights, and dashboard loading to `AnalyticsRepositoryContainer`, semantic summaries, evidence generators, and the transparent snapshot. Dashboard summaries now enumerate dynamic definitions rather than fixed `MetricType` mappings. Removed the production cache dependency on `ChartDataManager`; its only remaining singleton consumer is the app-compiled legacy integration demo. Replaced `docs/adding-metrics.md` with the canonical architecture. Verified by repository search, the full analytics suite, and Clove device build on 2026-07-18.
