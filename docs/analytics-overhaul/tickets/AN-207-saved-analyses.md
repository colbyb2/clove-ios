# AN-207 — Persisted saved analyses

- Status: done
- Phase: 3 — Relationship engine
- Dependencies: AN-006, AN-206

## Objective

Persist saved comparison configurations using stable metric IDs and recalculate them against current data.

## Scope

- Storage model for metric IDs, range policy, method, lag, filters, and display order.
- Migration path from any future/legacy aliases.
- Rename, deletion, and unavailable-metric states.

## Acceptance criteria

- Saves survive relaunch.
- Results are recalculated rather than freezing stale evidence.
- Renamed metrics resolve correctly.
- Deleted metrics produce a recoverable unavailable state.

## Verification

- Persistence, relaunch, rename, deletion, and migration tests.
- Clove scheme build.

## Completion notes

Added a GRDB migration, stable-ID saved configuration model, repository, recalculation against current data, rename/delete, range/method/lag storage, alias resolution, ordering, and recoverable unavailable-metric states.
