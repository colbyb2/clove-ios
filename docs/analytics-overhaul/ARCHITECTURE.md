# Analytics Architecture

## Current state

Clove has one production analytics path. `MetricProvider` remains a thin browser/presentation identity adapter, but provider summaries, metric details, Cross Reference, dashboards, discoveries, and insights all load canonical observations through `AnalyticsRepository`. The fixed `MetricType`/`ChartDataManager` stack and temporary chart engines have been removed.

## Target pipeline

```text
GRDB repositories
       ↓
AnalyticsRepository (explicit date range + data revision)
       ↓
MetricDefinition + MetricObservation
       ↓
Alignment / aggregation / coverage
       ↓
Descriptive, trend, pattern, and relationship engines
       ↓
AnalysisResult + EvidenceSummary
       ↓
Metric details, charts, comparisons, dashboard, insights
```

## Module responsibilities

### Metric definitions

Own stable identity, measurement level, units, valid range, directionality, reducers, missing policy, formatting, supported analyses, and recommended charts. Definitions do not query the database.

### Analytics repository

Loads source records for explicit `DateInterval` values and converts them to canonical observations. It batches related loads, exposes a data revision, and is the only data source used by analysis engines.

Phase 1 implements this boundary through `DefaultAnalyticsRepository`, with optional actor-isolated caching through `CachedAnalyticsRepository`. Dynamic metric definitions are resolved through durable database identities and compatibility aliases.

### Observation pipeline

Normalizes dates using the user's calendar and timezone, distinguishes missing from explicit zero, and applies metric-specific daily reducers. Raw events remain available for event-window analysis.

### Analysis engines

Pure or dependency-injected services calculate descriptive summaries, trends, patterns, pair relationships, lagged relationships, and event/outcome comparisons. They return structured results without UI strings or colors.

Phase 5 adds three pure layers: `AutomaticDiscoveryEngine` owns eligible-pair budgeting, corrected inference, deduplication, and ranking; `ContextAnalysisEngine` owns explicit cycle/flare grouping; and `PersonalBaselineEngine` owns robust personal-history comparisons. None of these engines reads persistence or user feedback.

### Presentation

Views convert structured results into plain-language explanations and appropriate Swift Charts. Presentation must display evidence and limitations supplied by the analysis result.

Phase 2 implements `MetricAnalysisSummary`, `AnalyticsChartResult`, and `AnalyticsMetricDetailView`. Chart family selection comes from metric semantics, period comparison uses equal calendar-day ranges, and presentation consumes structured summaries rather than recalculating generic statistics.

The compact Insights dashboard routes its Discover tile to one focused segmented destination. Feedback and hypotheses use `AdvancedInsightRepo` as local presentation metadata. Dismissal, rating, and save state filter presentation only and never alter an analysis result, p-value, q-value, effect, or rank.

### Rollout and diagnostics

`AnalyticsRolloutCoordinator` records only local migration state, attempt count, and a generic error code. Interrupted or failed migrations are retryable; GRDB transactions preserve source records. A default-on local flag can temporarily disable the Insights surface without selecting a second calculation stack.

`AnalyticsDiagnosticsRecorder` has a closed, aggregate-only local schema and no transmission client. It stores generic area/outcome/interaction/performance-bucket counts in `UserDefaults`; opt-out clears them immediately.

## Migration rules

- Providers may expose browser metadata, but may not own analytics meaning, summaries, statistics, or chart aggregation.
- New analysis code must depend on canonical definitions and datasets; `ChartDataManager` and `MetricType` no longer exist.
- No phase may leave two writable sources of truth.
- Compatibility aliases are identity-resolution data, not alternate calculations, and ambiguous aliases must remain unresolved.
- New analytics metrics must define semantics in the catalog, provide a source adapter, and add deterministic contract fixtures before a consumer adopts them.

## Concurrency and caching

- Repository and cache coordination should be actor-isolated.
- Cache keys include metric ID, exact date range, granularity, policy version, and data revision.
- Writes increment a shared data revision instead of relying on unrelated time-based cache expirations.
- Analysis engines should be cancellation-aware and publish UI state on the main actor.

## Verification boundary

`CloveAnalyticsTests` is the non-UI analytics test target. It uses deterministic synthetic fixtures and in-memory GRDB databases so semantic, repository, cache, identity, and later statistical regressions can run independently of previews and the shipping app. See `TESTING.md`.
