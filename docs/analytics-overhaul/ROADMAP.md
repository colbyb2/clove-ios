# Analytics Overhaul Roadmap

## Objective

Turn Clove's Insights area into a trustworthy, explainable, and useful personal analytics system. Every result should state what data was used, how it was calculated, how reliable it is, and what its limitations are.

## Delivery strategy

The overhaul is incremental. Existing screens remain functional while new contracts and adapters are introduced. Each phase has an exit gate; later phases may be refined as earlier decisions are validated, but their outcomes and dependencies remain stable.

## Phase 1 — Trustworthy foundation

Goal: establish one semantic and data-access foundation without redesigning the product UI.

- [x] [AN-001](tickets/AN-001-metric-semantics-contract.md) — Metric semantics contract
- [x] [AN-002](tickets/AN-002-metric-catalog.md) — Current metric catalog and policies
- [x] [AN-003](tickets/AN-003-canonical-observations.md) — Canonical observations and missing states
- [x] [AN-004](tickets/AN-004-unified-analytics-repository.md) — Unified date-range analytics repository
- [x] [AN-005](tickets/AN-005-data-revision-cache.md) — Data revisions and cache invalidation
- [x] [AN-006](tickets/AN-006-stable-dynamic-metric-ids.md) — Stable dynamic metric identities
- [x] [AN-007](tickets/AN-007-analytics-test-harness.md) — Statistical test harness and fixtures

Exit gate: every current metric can produce canonical observations for an explicit range; missing and zero are distinct; repository writes invalidate analytics; reference fixtures pass.

Checkpoint status: satisfied on 2026-07-18. Phase 2 may begin with AN-101.

## Phase 2 — Unified charts and metric details

Goal: move charting onto the trusted pipeline and give each metric a useful, type-aware detail experience.

- [x] [AN-101](tickets/AN-101-analysis-summary-model.md) — Typed analysis summaries
- [x] [AN-102](tickets/AN-102-chart-data-pipeline.md) — Unified chart pipeline
- [x] [AN-103](tickets/AN-103-type-aware-charts.md) — Type-aware visualizations
- [x] [AN-104](tickets/AN-104-metric-detail-screen.md) — Rich metric detail screen
- [x] [AN-105](tickets/AN-105-period-comparison.md) — Period comparison and custom ranges
- [x] [AN-106](tickets/AN-106-chart-interaction-accessibility.md) — Interaction and accessibility

Exit gate: all Metric Explorer charts use the new pipeline, preserve gaps, display correct summaries, support comparison, and pass accessibility checks.

Checkpoint status: satisfied on 2026-07-18. Phase 3 may begin with AN-201.

## Phase 3 — Relationship engine

Goal: replace Pearson-only correlation with analysis appropriate to each metric pair.

- [x] [AN-201](tickets/AN-201-pair-alignment-coverage.md) — Pair alignment and coverage
- [x] [AN-202](tickets/AN-202-statistical-method-selection.md) — Statistical method selection
- [x] [AN-203](tickets/AN-203-inference-confidence.md) — Inference and confidence intervals
- [x] [AN-204](tickets/AN-204-lagged-analysis.md) — Lagged relationships
- [x] [AN-205](tickets/AN-205-event-outcome-analysis.md) — Event/outcome analysis
- [x] [AN-206](tickets/AN-206-comparison-experience.md) — Redesigned comparison experience
- [x] [AN-207](tickets/AN-207-saved-analyses.md) — Persisted saved analyses

Exit gate: relationship results are type-aware, tested against reference values, disclose coverage and limitations, and never use causal language.

Checkpoint status: satisfied on 2026-07-18. Phase 4 may begin with AN-301.

## Phase 4 — Insights and dashboard

Goal: rebuild generated insights and the dashboard using one evidence model.

- [x] [AN-301](tickets/AN-301-insight-evidence-model.md) — Insight evidence model
- [x] [AN-302](tickets/AN-302-trend-pattern-generators.md) — Trend and pattern generators
- [x] [AN-303](tickets/AN-303-insights-home.md) — Redesigned Insights home
- [x] [AN-304](tickets/AN-304-wellbeing-snapshot.md) — Transparent wellbeing snapshot
- [x] [AN-305](tickets/AN-305-remove-legacy-analytics.md) — Retire legacy analytics stack

Exit gate: dashboard and insights use real unified results, explain their evidence, contain no placeholder analysis, and no longer depend on `ChartDataManager`.

Checkpoint status: satisfied on 2026-07-18. Phase 5 may begin with AN-401.

## Phase 5 — Advanced discovery

Goal: find richer personal patterns while controlling false discoveries.

- [x] [AN-401](tickets/AN-401-automatic-discovery.md) — Automatic discovery and FDR control
- [x] [AN-402](tickets/AN-402-cycle-flare-analysis.md) — Cycle- and flare-aware analysis
- [x] [AN-403](tickets/AN-403-personal-baselines.md) — Personalized baselines
- [x] [AN-404](tickets/AN-404-insight-feedback-hypotheses.md) — Feedback and hypotheses

Exit gate: automatic discoveries meet minimum evidence rules, context-aware analyses are explainable, and users can manage what is useful to them.

Checkpoint status: satisfied on 2026-07-18. Phase 6 may begin with AN-501.

## Phase 6 — Validation and rollout

Goal: ship safely, measure quality, and remove migration scaffolding.

- [x] [AN-501](tickets/AN-501-validation-performance.md) — Validation and performance
- [x] [AN-502](tickets/AN-502-feature-flag-migration.md) — Feature flag and migration rollout
- [x] [AN-503](tickets/AN-503-privacy-safe-telemetry.md) — Privacy-safe product telemetry
- [x] [AN-504](tickets/AN-504-cleanup-documentation.md) — Cleanup and documentation

Exit gate: the new experience is the default, performance budgets pass, sensitive values never leave the device, and obsolete code and adapters are removed.

Checkpoint status: satisfied on 2026-07-18. The overhaul is generally available.

## Release checkpoints

1. Foundation checkpoint after Phase 1.
2. First user-visible release after Phase 2.
3. Trustworthy comparison release after Phase 3.
4. Full Insights replacement after Phase 4.
5. Advanced discovery release after Phase 5.
6. General availability after Phase 6.
