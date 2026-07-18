# AN-101 — Typed analysis summaries

- Status: done
- Phase: 2 — Unified charts and metric details
- Dependencies: Phase 1 exit gate

## Objective

Create metric-aware descriptive and trend result models that presentation code can render without recalculating statistics.

## Scope

- Implement typed summaries for continuous, ordinal, count, binary, categorical, event, and percentage metrics.
- Include coverage, denominators, period comparison, trend direction, favorability, and limitations.
- Keep result models independent of SwiftUI.

## Acceptance criteria

- No generic average or percentage-change field is required for incompatible metric types.
- Results expose raw numeric evidence and formatted presentation inputs separately.
- Sparse and zero-denominator cases return explicit limitations.
- Reference fixtures pass.

## Verification

- Unit tests for every measurement level and edge case.
- Clove scheme build.

## Completion notes

- Added SwiftUI-independent typed summary values for numeric, count, binary, categorical, event, and weighted-percentage metrics.
- Summaries expose coverage, denominators, latest observation, trend direction and favorability, notable dates, previous-period evidence, and explicit limitations.
- Sparse coverage, unavailable comparisons, insufficient trend samples, event-source ambiguity, and zero denominators remain explicit instead of producing placeholder values.
- Added reference tests for every measurement family, directionality, comparison coverage, and degenerate inputs.
