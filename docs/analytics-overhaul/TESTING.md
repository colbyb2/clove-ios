# Analytics Testing

`CloveAnalyticsTests` is the XCTest target for semantic contracts, data access, caching, identity migrations, and statistical regressions. Tests must not depend on SwiftUI previews, the user's application database, wall-clock time, or nondeterministic randomness.

## Run the suite

Use an installed simulator runtime and device name:

```bash
xcodebuild -project Clove.xcodeproj \
  -scheme Clove \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' \
  -derivedDataPath /tmp/CloveAnalyticsDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  test
```

CI may substitute another supported simulator destination. The command must keep the shared `Clove` scheme so the analytics test target is discovered.

## Fixture conventions

- Use `AnalyticsSyntheticFixtures` for increasing, decreasing, constant, noisy, sparse, binary, ordinal, categorical, and duplicate datasets.
- Pass an explicit seed to every randomized fixture. A failing test must reproduce with the same seed.
- Use `TestDatabaseManager` for repository and migration tests. Each test gets an isolated in-memory database and runs production migrations.
- Create dates through the test date helpers with an explicit calendar and timezone. Include DST-boundary coverage whenever daily grouping or range construction changes.
- State the expected semantic distinction: missing, explicit zero, explicit none, and not applicable are different outcomes.

## Reference values and tolerances

- Prefer exact equality for IDs, counts, dates, categories, flags, and deterministic ordering.
- Use `1e-9` absolute accuracy for direct formulas and hand-calculated reference values.
- Iterative or platform statistical routines may use `1e-6` only when the test documents why the wider tolerance is required.
- Do not loosen a tolerance to hide a regression. Confirm the reference calculation and numerical method first.

## Adding a regression test

1. Put the test beside the closest contract area in `CloveAnalyticsTests`.
2. Add a reusable deterministic fixture to `AnalyticsSyntheticFixtures` when more than one test will need it.
3. Cover a normal case, a known-negative case, and relevant degenerate states such as no data, sparse dates, constant values, zero variance, duplicates, or DST.
4. Assert structured evidence and limitations as well as the headline value.
5. Run the analytics suite, the Clove device build, and `git diff --check` before marking the ticket done.

## Phase 2 accessibility review

- Verify chart summaries and every range/comparison control with VoiceOver.
- Verify summary-card reflow at accessibility text sizes.
- Verify range changes with Reduce Motion enabled.
- Verify chart marks, selected annotations, and reference lines in light and dark themes.
- Verify chart scrubbing without requiring precision tapping and confirm a chart tap never forces full screen.

## Phase 3 comparison review

- Verify factor/outcome selection, the lag slider, saved-analysis menus, and disclosure groups with VoiceOver.
- Verify numeric scatter, categorical/grouped, event/control, and lag-profile plots at accessibility text sizes.
- Confirm coverage, matched sample count, method, interval, and limitations remain readable without interpreting color.
- Confirm positive-lag direction is announced as factor-before-outcome and all result copy uses association language.
- Regression coverage lives in `Phase3RelationshipTests.swift`, including sparse/DST alignment, reference statistics, lag signals, event overlap, and saved-analysis persistence.

## Phase 4 insights review

- Verify no-data, sparse, rich, and partially available snapshots; missing components must say “Not recorded” and carry 0% weight.
- Verify each generated discovery exposes its evidence calculation, observed/eligible days, quality label, and limitations with VoiceOver.
- Verify each compact dashboard tile opens its focused detail screen, metric-change rows link to metric details, and Compare opens the comparison flow.
- Verify dynamic metrics appear in coverage, dashboard summaries, and insight generation when their semantic definition permits it.
- Confirm no production Insights or dashboard consumer references `ChartDataManager` or fixed `MetricType` loading.
- Regression coverage lives in `Phase4InsightsTests.swift`, including stable identity, copy policy, robust trends, sparse/noise cases, weekday repetition, volatility, streak missingness, and snapshot weighting/comparison.

## Phase 5 discovery review

- Verify the compact Discover tile opens Findings, Context, Baselines, and Hypotheses without adding dashboard height.
- Verify an automatic finding shows method, effect, adjusted q-value, matching days, coverage, exploratory language, and limitations without implying causation.
- Verify useful/not-useful, bookmark, and 30-day dismissal controls with VoiceOver; dismissed findings remain hidden until expiry and feedback never changes evidence.
- Verify missing or irregular cycle history produces no phase inference, flare comparisons show both group sizes, and baseline cards expose their observation count and history period.
- Verify hypothesis creation rejects identical metric pairs and clearly labels the saved question as a tracking plan rather than proof.
- Regression coverage lives in `Phase5AdvancedAnalyticsTests.swift`, including reference FDR correction, seeded null and injected signals, hard budgets, complete/incomplete/irregular context, robust/sparse/gapped baselines, dismissal expiry, and local persistence.

## Phase 6 release review

- Run `Phase6ProductionReadinessTests.swift` for ten-year refresh, indexed lookup, chart density, rollout interruption/retry, record preservation, diagnostic opt-out, and prohibited payload fields.
- Confirm the repository remains one serialized read and no more than nine statements regardless of metric count.
- Search production code for `ChartDataManager`, `MetricType`, temporary chart engines, and legacy observation adapters; no reference may remain.
- Confirm Local Diagnostics has no network sender and disabling it clears stored aggregate counters.
- Run the full simulator suite, a Release configuration device build, documentation link audit, and `git diff --check`.
