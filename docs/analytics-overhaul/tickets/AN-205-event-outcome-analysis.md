# AN-205 — Event/outcome analysis

- Status: done
- Phase: 3 — Relationship engine
- Dependencies: AN-201, AN-203

## Objective

Compare health outcomes around meals, activities, medications, bowel events, and other timestamped occurrences.

## Scope

- Exposed/unexposed and before/after windows.
- Same-day and next-day outcomes.
- Event frequency, duration, intensity, category, and eligible-control rules where available.

## Acceptance criteria

- Results include group sizes, coverage, effect estimate, uncertainty, and limitations.
- Multiple events and overlapping windows have a defined policy.
- As-needed and scheduled medication are not conflated.
- Copy uses association language only.

## Verification

- Synthetic event-window fixtures and overlap edge cases.
- Clove scheme build.

## Completion notes

Implemented same-day and next-day exposed/control comparisons with unique exposure days, overlap handling, eligible controls, group sizes, mean differences, intervals, and association-only limitations.
