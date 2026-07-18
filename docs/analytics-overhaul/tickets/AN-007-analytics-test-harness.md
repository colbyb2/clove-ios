# AN-007 — Statistical test harness and fixtures

- Status: done
- Phase: 1 — Trustworthy foundation
- Dependencies: AN-001, AN-003

## Objective

Create a real XCTest-based analytics suite with trusted reference fixtures and reusable synthetic datasets.

## User outcome

Analytics changes can be validated for correctness instead of relying on visual inspection.

## Scope

- Add or configure an analytics test target.
- Create deterministic fixtures for trends, noise, missingness, counts, binary events, ordinal values, and categorical distributions.
- Add helpers for date/timezone and database-backed tests.
- Establish numeric tolerance and reference-value conventions.
- Document how to add statistical regression tests.

## Non-goals

- Test every later-phase algorithm before it exists.
- UI snapshot infrastructure beyond what Phase 1 needs.

## Acceptance criteria

- Tests run independently of previews and the shipping app target.
- Fixtures include known-positive and known-negative cases.
- Randomized fixtures use deterministic seeds.
- Tests cover constant series, zero variance, sparse dates, DST, and duplicates.
- CI-compatible command is documented.

## Verification

- New test target passes from `xcodebuild test` on a supported simulator.
- Clove scheme build.

## Completion notes

- Added the `CloveAnalyticsTests` XCTest target to the shared Clove scheme.
- Added in-memory GRDB helpers plus deterministic synthetic fixtures for trends, noise, sparse dates, binary events, ordinal/categorical values, constant series, and duplicates.
- Migrated the Phase 1 semantic and observation contract checks into XCTest and added database-backed repository, cache, migration, DST, cancellation, and concurrency coverage.
- Established reference-value and numeric-tolerance conventions in `TESTING.md`, including the CI-compatible command and fixture extension workflow.
- Verified 12 tests passing on an iPhone 17 simulator running iOS 26.2 on 2026-07-18.
