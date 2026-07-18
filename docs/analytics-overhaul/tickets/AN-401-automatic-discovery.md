# AN-401 — Automatic discovery and FDR control

- Status: done
- Phase: 5 — Advanced discovery
- Dependencies: Phase 4 exit gate

## Objective

Scan eligible metric relationships without turning repeated testing into false discoveries.

## Scope

- Candidate eligibility, effect-size thresholds, minimum coverage, duplicate suppression, false-discovery-rate correction, ranking, and analysis-budget limits.

## Acceptance criteria

- Multiple-comparison correction is applied per discovery run.
- Ranking considers effect, uncertainty, coverage, recency, and actionability.
- Noise-only synthetic populations meet a documented false-positive budget.
- Discoveries disclose that they are exploratory.

## Verification

- Large synthetic null and injected-signal datasets.
- Performance test and Clove scheme build.

## Completion notes

Implemented a deterministic, budget-limited pair scan with coverage and sample eligibility, effect thresholds, Benjamini–Hochberg correction, stable deduplication, and evidence-aware ranking. Exploratory limitations and adjusted q-values are visible in Discover. Seeded null, injected-signal, correction-reference, and hard-budget tests pass.
