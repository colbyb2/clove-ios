# AN-402 — Cycle- and flare-aware analysis

- Status: done
- Phase: 5 — Advanced discovery
- Dependencies: AN-205, AN-301

## Objective

Analyze metric changes by cycle phase and flare state while handling incomplete context.

## Scope

- Cycle-phase grouping, flare versus non-flare comparisons, phase coverage, within-user baselines, and context overlays.

## Acceptance criteria

- Cycle analysis requires sufficient repeated observations per phase.
- Missing cycle data is not inferred.
- Flare comparisons disclose group sizes and coverage.
- Results do not diagnose conditions or recommend treatment changes.

## Verification

- Complete, irregular, missing, and no-cycle fixtures.
- Clove scheme build.

## Completion notes

Implemented repeated phase summaries only between explicit cycle starts and only for complete 21–45 day intervals. Flare comparisons use explicit logged flare state and show both group sizes. Missing, incomplete, irregular, repeated-cycle, and flare fixtures pass; UI copy remains descriptive and non-diagnostic.
