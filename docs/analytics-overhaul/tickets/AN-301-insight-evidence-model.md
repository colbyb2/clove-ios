# AN-301 — Insight evidence model

- Status: done
- Phase: 4 — Insights and dashboard
- Dependencies: Phase 3 exit gate

## Objective

Define a structured insight result containing evidence, provenance, relevance, limitations, priority, and presentation hints without embedding unsupported advice.

## Scope

- Insight kinds, effect estimates, evidence summaries, date ranges, quality labels, associated metric IDs, limitations, and stable identity/deduplication.
- Plain-language presentation inputs separate from calculations.

## Acceptance criteria

- Every insight can answer “Why am I seeing this?”
- Confidence derives from evidence rather than hard-coded values.
- Equivalent recalculations deduplicate predictably.
- Medical and causal language is prohibited by generation rules.

## Verification

- Model and copy-policy tests.
- Clove scheme build.

## Completion notes

Implemented structured evidence, provenance, limitations, quality, presentation hints, copy policy, evidence-derived confidence, and stable generator/metric identities. Added deterministic model, deduplication, explanation, and prohibited-copy tests. Verified by the full analytics suite and Clove device build on 2026-07-18.
