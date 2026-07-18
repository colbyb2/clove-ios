# Analytics Performance Budgets

These are release gates for the supported baseline: iPhone 12-class hardware or newer, iOS 17+, with a ten-year daily history. Simulator tests are regression guards; device profiling should be repeated before changing a budget.

| Workload | Budget | Enforcement |
|---|---:|---|
| Repository database access | 1 serialized read, at most 9 statements | `AnalyticsRepositoryTests` |
| Ten-year unified refresh | under 2 seconds | `AnalyticsPerformanceBudgetTests` |
| 500 indexed metric lookups | under 250 ms | `AnalyticsPerformanceBudgetTests` |
| Automatic discovery | at most 60 tested pairs | production constant and Phase 5/6 tests |
| Ten-year chart density | at most 132 monthly points per series | `AnalyticsPerformanceBudgetTests` |
| Cache cancellation | cancelled work is not loaded or cached | `AnalyticsRevisionCacheTests` |

## 2026-07-18 profiling report

- Environment: iPhone 17 / iOS 26.2 simulator, Debug XCTest build on Apple silicon.
- Ten-year unified repository refresh: 0.439 seconds against the 2-second budget.
- Ten-year indexed lookup plus monthly chart density: 0.048 seconds against the 250-ms lookup budget and 132-point density cap.
- Query shape: one GRDB read and nine fixed statements, independent of metric count.
- Memory control: canonical observations are stored once plus a dictionary of per-metric arrays referencing the same value-type records; long-range charts aggregate monthly and do not render daily marks.
- Responsiveness: cache and repository boundaries check cancellation before loading, after source loading, and after canonical reduction. Superseded detail requests also use generation ownership.

Use Instruments Time Profiler and Allocations on a physical baseline device before raising any limit. A regression must be explained and approved in `DECISIONS.md`; budgets must not be loosened solely to make a test pass.
