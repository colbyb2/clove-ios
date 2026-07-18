# AN-003 — Canonical observations and missing states

- Status: done
- Phase: 1 — Trustworthy foundation
- Dependencies: AN-001, AN-002

## Objective

Introduce a canonical, typed observation model that preserves recorded values, explicit absence, missingness, eligibility, timestamps, and source identity.

## User outcome

Untracked days no longer appear as false zeros, and chart gaps and rate denominators become trustworthy.

## Scope

- Define `MetricObservation`, observation state, typed value, source reference, and quality flags.
- Normalize day boundaries using an injected calendar and timezone.
- Preserve raw events for event-window analysis.
- Implement daily reduction according to the metric catalog.
- Add adapters for `DailyLog`, food, activity, bowel, cycle, and medication sources.

## Non-goals

- Replace persistence models.
- Calculate trends or correlations.
- Change existing screens.

## Acceptance criteria

- Missing and explicit zero/none are different states.
- Multiple same-day events reduce deterministically without losing raw events.
- Bowel frequency and Bristol type remain distinct.
- DST and timezone changes do not duplicate or lose days.
- Observation identity is stable across repeated loads.
- Adapters cover every Phase 1 catalog definition.

## Verification

- Fixtures for missing, explicit none, duplicate events, DST, timezone changes, and edited records.
- Adapter tests for every source repository.
- Clove scheme build.

## Completion notes

- Added typed canonical observation, observation-state, value, source-reference, quality-flag, and raw-event contracts.
- Added injected calendar/timezone day normalization and deterministic catalog-driven daily reduction. Raw events remain unchanged when their daily observations reduce.
- Added adapters for daily log fields, symptoms, medication adherence and occurrences, food, activity, bowel, and cycle records, plus a database-independent composition pipeline for `AN-004`.
- Positive-event adapters emit only established occurrences. They do not synthesize negative days; invalid Bristol values are flagged and excluded from observed daily values while their raw event is retained.
- Added pure fixtures for missing versus zero/none, duplicates, DST, timezones, edited identity, and deterministic ordering, plus app-model fixtures covering every Phase 1 catalog source.
- Verified the executable observation contract suite and a code-signing-disabled Clove device build on 2026-07-18.
