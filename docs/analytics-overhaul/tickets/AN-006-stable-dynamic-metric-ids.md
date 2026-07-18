# AN-006 — Stable dynamic metric identities

- Status: done
- Phase: 1 — Trustworthy foundation
- Dependencies: AN-001, AN-002

## Objective

Ensure symptoms, medications, foods, and activities keep the same analytic identity when renamed and cannot collide through normalized names.

## User outcome

Historical charts and saved analyses survive renames and similarly named items.

## Scope

- Define stable IDs for each dynamic metric family.
- Prefer database record identity over display-name slugs.
- Add migrations or identity mapping where source records lack stable IDs.
- Preserve compatibility aliases for old metric IDs during migration.
- Define behavior for deleted and recreated entities.

## Non-goals

- Redesign tracker-management UI.
- Merge user records automatically based only on similar names.

## Acceptance criteria

- Renaming does not split history.
- Distinct records with colliding normalized names remain distinct.
- Saved IDs can resolve after app relaunch.
- Historical inactive symptoms remain analyzable.
- Migration is idempotent and preserves existing data.

## Verification

- Migration tests for rename, collision, deletion, and relaunch.
- Clove scheme build against a migrated fixture database.

## Completion notes

- Added durable identities and compatibility aliases for symptom, medication, meal, and activity metric families.
- Added an idempotent migration that assigns existing meal/activity rows stable identities and records aliases for current and historical symptoms/medications.
- Food and activity writes now preserve identity through edits and rename the identity's display label without splitting historical observations.
- Legacy aliases may map to multiple canonical IDs when old slug normalization collided; ambiguous aliases intentionally do not resolve to an arbitrary metric.
- Deleting and recreating a symptom or medication creates a new identity while the historical inactive identity remains analyzable. Meal/activity identities remain reusable by the same exact normalized name because their durable dimension records are retained.
- Added migration, rename, collision, deletion/recreation, relaunch, and historical-observation tests.
