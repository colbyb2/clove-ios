# AN-502 — Feature flag and migration rollout

- Status: done
- Phase: 6 — Validation and rollout
- Dependencies: AN-501

## Objective

Roll out the new Insights experience safely with reversible migration controls.

## Scope

- Local feature flag, migration state, fallback behavior, data migration recovery, phased default changes, and removal criteria.

## Acceptance criteria

- Users never lose source health records when toggling experiences or migrating.
- Failed migrations are recoverable and observable without exposing health values.
- New installs and upgraded installs follow documented paths.
- Flag removal criteria and deadline are recorded.

## Verification

- Fresh install, multiple upgrade paths, interruption, rollback, and retry tests.
- Clove scheme build.

## Completion notes

Added local migration state with interruption detection, generic failure codes, retry UI, new/upgrade install paths, and a default-on local unified-Insights flag. Disabling Insights never mutates source records and uses a safe unavailable screen rather than the retired legacy calculations. Fresh, upgrade, rollback, interruption, failure, and retry tests pass. Removal criterion: remove the flag after 2026-08-15 if no migration recovery defect requires rollback; migration state remains for support diagnostics.
