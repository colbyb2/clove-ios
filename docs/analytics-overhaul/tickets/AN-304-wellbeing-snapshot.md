# AN-304 — Transparent wellbeing snapshot

- Status: done
- Phase: 4 — Insights and dashboard
- Dependencies: AN-101, AN-303

## Objective

Replace or reframe the opaque Health Score with transparent component summaries users can understand and optionally personalize.

## Scope

- Evaluate snapshot versus composite score through a documented product decision.
- Show mood, pain, energy, symptoms, adherence, and coverage components without double-counting dynamic metrics.
- If a composite remains, expose weights and calculation details.

## Acceptance criteria

- Previous-period comparison is genuinely calculated.
- Missing components do not silently become poor scores.
- Users can inspect every included component and weight.
- The UI states that the snapshot is not medical advice.

## Verification

- Component, missingness, weighting, and period-comparison tests.
- Clove scheme build.

## Completion notes

Selected a transparent component snapshot instead of a headline health score. Mood, pain, energy, symptoms, and adherence use actual current/prior summaries; unavailable components have zero weight and available components share equal visible weight. Symptoms are combined once. Added missingness, comparison, favorability, weighting, and double-counting tests. Verified by the full analytics suite and Clove device build on 2026-07-18.
