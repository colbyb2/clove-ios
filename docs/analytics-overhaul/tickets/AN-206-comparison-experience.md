# AN-206 — Redesigned comparison experience

- Status: done
- Phase: 3 — Relationship engine
- Dependencies: AN-202, AN-203, AN-204, AN-205

## Objective

Replace the current correlation-only screen with a comparison experience that explains method, evidence, coverage, lag, and limitations.

## Scope

- Outcome/factor selection, recommended method, lag controls, appropriate plot type, evidence summary, technical details, and daily drill-down.

## Acceptance criteria

- Plot type matches metric pair semantics.
- Users can understand direction without interpreting coefficient signs.
- Sample size, coverage, interval, method, and limitations are visible.
- No result claims one metric causes another.

## Verification

- UI tests across continuous, binary, ordinal, categorical, and event comparisons.
- Accessibility review and Clove scheme build.

## Completion notes

Replaced the correlation result path with a factor/outcome comparison experience containing semantic plots, plain-language direction, lag controls, evidence, coverage, technical details, limitations, and matching-day drill-down.
