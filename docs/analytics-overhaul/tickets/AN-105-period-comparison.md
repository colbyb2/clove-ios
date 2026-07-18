# AN-105 — Period comparison and custom ranges

- Status: done
- Phase: 2 — Unified charts and metric details
- Dependencies: AN-102, AN-104

## Objective

Support comparable previous periods and user-selected ranges throughout metric details.

## Scope

- Wire custom ranges into repository requests.
- Generate equal-duration prior periods.
- Add overlays or side-by-side summaries appropriate to metric type.
- Handle unequal coverage explicitly.

## Acceptance criteria

- Selected range is the range analyzed, not merely a display label.
- Period boundaries are timezone-safe and non-overlapping.
- Comparison results show both coverage values.
- All-time mode uses an explicit comparison policy or disables comparison.

## Verification

- Boundary, leap-year, DST, and unequal-coverage tests.
- Clove scheme build.

## Completion notes

- Added inclusive custom date picking backed by exact half-open repository intervals.
- Added an optional equal-day previous period that ends exactly at the selected range start and reports both coverage values.
- Calendar arithmetic, rather than elapsed seconds, preserves equal day counts across DST and leap-day ranges.
- All Time uses an explicit 1970-to-tomorrow interval and disables previous-period comparison.
- Added DST, leap-year, non-overlap, unequal-coverage, and comparison-value tests.
