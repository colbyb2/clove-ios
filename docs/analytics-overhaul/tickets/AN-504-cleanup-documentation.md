# AN-504 — Cleanup and documentation

- Status: done
- Phase: 6 — Validation and rollout
- Dependencies: AN-502, AN-503

## Objective

Remove rollout scaffolding, resolve documentation debt, and leave one maintainable analytics architecture.

## Scope

- Remove expired feature flags, migration aliases, temporary adapters, dead previews, obsolete caches, and deprecated models.
- Finalize metric-authoring, analysis-method, privacy, testing, and troubleshooting guides.
- Archive completed tickets without deleting their history.

## Acceptance criteria

- No untracked compatibility TODO remains.
- `docs/adding-metrics.md` describes the final contracts and required tests.
- Architecture and data-semantics documents match production behavior.
- Full tests and release build pass.

## Verification

- Dead-code/reference audit, documentation link check, full test suite, and release build.

## Completion notes

Removed `ChartDataManager`, fixed `MetricType`, legacy semantic/observation adapters, app-compiled integration/performance demos, and unused chart engines. Metric browser summaries and Cross-Reference previews now consume the unified repository. Final metric-authoring, methods, privacy, performance, testing, and troubleshooting guides are linked and the complete test/release verification passes.
