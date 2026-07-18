# Adding an Analytics Metric to Clove

Clove has one analytics path: semantic definition → canonical observations → `AnalyticsDataset` → shared summaries, charts, relationships, and insights. Do not add new data loading to `ChartDataManager`, a dashboard, or an individual chart.

## 1. Define the metric’s meaning

Add a `MetricDefinition` to `Clove/Metrics/Core/MetricCatalog.swift`. A definition must explicitly choose:

- a durable `MetricID` and source;
- measurement level, unit, valid domain, and health directionality;
- daily and longer-period aggregation rules;
- what an unrecorded day means;
- supported analyses, minimum sample counts, visualizations, and formatting.

Missing, zero, explicit none, and not applicable are different states. Positive-event sources such as meals and activities must not manufacture zeroes for days without records.

For a static metric, add the definition to `staticDefinitions`. For a user-created family, add a catalog factory like `symptom(id:name:isBinary:)`; dynamic IDs must come from `DynamicMetricIdentity`, not from a display-name slug.

## 2. Produce canonical observations

Map the source record in `Clove/Metrics/Services/MetricObservationAdapters.swift` and route it through `MetricObservationPipeline`. Adapters are pure transformations: database access belongs in `GRDBAnalyticsSourceLoader`.

Return typed `MetricObservation` values with source references. Preserve original event timestamps as `MetricRawEvent` when event-window analysis may need them. Let `MetricDayNormalizer` apply the definition’s reducer; do not aggregate independently in a view.

If the metric needs a new table or column:

1. add the GRDB migration;
2. load the range-bounded records in `GRDBAnalyticsSourceLoader`;
3. include them in `AnalyticsSourceSnapshot` and the observation pipeline;
4. call `AnalyticsRevisionClock.shared.markDataChanged()` after successful writes.

## 3. Expose it to the interface

The unified repository discovers all catalog definitions and dynamic identities. If the metric should appear in the current metric browser, add a thin `MetricProvider` compatibility adapter and register it with `MetricRegistry`. Its `catalogMetricDefinition` must resolve to the same canonical ID. It must not implement separate analytics or chart statistics.

`AnalyticsMetricDetailView`, `MetricAnalysisSummaryEngine`, `AnalyticsChartPipeline`, the relationship engine, and `InsightGenerator` select behavior from `MetricDefinition`. Unsupported modules are omitted instead of falling back to a generic line chart or fabricated statistic.

## 4. Verify the contract

Add deterministic tests under `CloveAnalyticsTests` covering:

- valid definition semantics and stable identity;
- observed, missing, explicit-zero, and duplicate-source behavior;
- daily reduction and longer-period aggregation;
- exact half-open date-range loading and coverage;
- the selected summary/chart family;
- supported relationship and insight behavior, including sparse data;
- revision invalidation after every write path.

Run:

```bash
xcodebuild -project Clove.xcodeproj \
  -scheme Clove \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' \
  -derivedDataPath /tmp/CloveAnalyticsDerivedData \
  CODE_SIGNING_ALLOWED=NO test

xcodebuild -project Clove.xcodeproj \
  -scheme Clove \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/CloveDerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

## Review checklist

- The definition is the only source of analytic meaning.
- Repository reads are range-bounded and do not grow per metric.
- Unrecorded days follow the declared policy.
- Dynamic identity survives rename and relaunch.
- Charts, summaries, comparisons, and insights consume the unified dataset.
- User-facing conclusions disclose coverage, evidence, and limitations.
- No code was added to `ChartDataManager` or legacy aggregation/statistics services.
